-- Unit tests for the key-value-map-operations plugin

local handler_module = require("kong.plugins.key-value-map-operations.handler")
local KvmHandler = handler_module

-- Mock dependencies
local mock_kong = {}
local mock_kvm = {}

local function reset_mocks()
    -- Reset mock KVM
    mock_kvm = {
        store = {},
        get = function(self, key)
            if key == "error_key" then return nil, "simulated get error" end
            return self.store[key]
        end,
        set = function(self, key, value, ttl)
            if key == "error_key" then return nil, "simulated set error" end
            self.store[key] = value
            return true
        end,
        delete = function(self, key)
            self.store[key] = nil
        end,
    }

    -- Reset mock Kong object
    mock_kong = {
        request = {
            get_header = function(name) return mock_kong.request.headers[name] end,
            get_query = function() return mock_kong.request.query_args end,
            get_raw_body = function() return mock_kong.request.raw_body, nil end,
            headers = {},
            query_args = {},
            raw_body = "",
        },
        response = {
            exit_called = false,
            exit_args = {},
            exit = function(status, body)
                mock_kong.response.exit_called = true
                mock_kong.response.exit_args = { status = status, body = body }
                error("kong.response.exit called") -- Simulate Kong exit
            end,
        },
        service = {
            request = {
                headers = {},
                set_header = function(key, val) mock_kong.service.request.headers[key] = val end,
            }
        },
        ctx = {
            shared = {},
        },
        log = {
            err_called = false,
            err_args = nil,
            err = function(...) mock_kong.log.err_called = true; mock_kong.log.err_args = {...} end,
            debug = function(...) end,
        },
        shared = {
            my_kvm = mock_kvm,
        },
    }
    -- Inject mocks
    _G.kong = mock_kong
end

local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(ok or string.find(err, "kong.response.exit called"), "Test should either pass or simulate Kong exit")
end

-- --- Test Suite ---

describe("key-value-map-operations handler", function()

    before_each(reset_mocks)

    it("Scenario 1: 'put' operation with literal key and header value", function()
        local conf = {
            policy = "local",
            kvm_name = "my_kvm",
            operation_type = "put",
            key_source_type = "literal",
            key_source_name = "my-key-1",
            value_source_type = "header",
            value_source_name = "X-Value-To-Store",
        }
        mock_kong.request.headers["X-Value-To-Store"] = "stored_value_123"

        local instance = KvmHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.falsy(mock_kong.response.exit_called, "Should not exit on success")
        assert.are.equal("stored_value_123", mock_kvm.store["my-key-1"])
    end)

    it("Scenario 2: 'get' operation with query key and output to shared_context", function()
        mock_kvm.store["user-id-456"] = "user-profile-data"
        local conf = {
            policy = "local",
            kvm_name = "my_kvm",
            operation_type = "get",
            key_source_type = "query",
            key_source_name = "userId",
            output_destination_type = "shared_context",
            output_destination_name = "retrieved_user_data",
        }
        mock_kong.request.query_args["userId"] = "user-id-456"

        local instance = KvmHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.falsy(mock_kong.response.exit_called, "Should not exit on success")
        assert.are.equal("user-profile-data", mock_kong.ctx.shared.retrieved_user_data)
    end)

    it("Scenario 3: 'delete' operation with key from shared_context", function()
        mock_kvm.store["key-to-delete"] = "some-value"
        mock_kong.ctx.shared.key_for_deletion = "key-to-delete"
        local conf = {
            policy = "local",
            kvm_name = "my_kvm",
            operation_type = "delete",
            key_source_type = "shared_context",
            key_source_name = "key_for_deletion",
        }

        local instance = KvmHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.falsy(mock_kong.response.exit_called, "Should not exit on success")
        assert.is_nil(mock_kvm.store["key-to-delete"])
    end)

    it("Scenario 4: 'get' operation for a non-existent key should not error", function()
        local conf = { policy = "local", kvm_name = "my_kvm", operation_type = "get", key_source_type = "literal", key_source_name = "non-existent-key", output_destination_type = "shared_context", output_destination_name = "output" }
        local instance = KvmHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)
        assert.falsy(mock_kong.response.exit_called, "Should not exit for a missing key")
        assert.is_nil(mock_kong.ctx.shared.output, "Output should be nil for a missing key")
    end)
end)