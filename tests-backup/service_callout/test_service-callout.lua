-- Unit tests for the service-callout plugin

local handler_module = require("kong.plugins.service-callout.handler")
local ServiceCalloutHandler = handler_module

-- Mock dependencies
local mock_kong = {}
local mock_http_client = {}

local function reset_mocks()
    mock_http_client = {
        set_timeout_called_with = nil,
        request_uri_called_with = nil,
        should_error = false,
        response = {
            status = 200,
            headers = { ["Content-Type"] = "application/json" },
            body = '{"data":"mock_response"}',
            read_body = function(self) return self.body end,
        },
        set_timeout = function(self, timeout)
            self.set_timeout_called_with = timeout
        end,
        request_uri = function(self, uri, options)
            self.request_uri_called_with = { uri = uri, options = options }
            if self.should_error then
                return nil, "connection timed out"
            end
            return self.response, nil
        end,
        encode_queries = function(self, t)
            local parts = {}
            for k, v in pairs(t) do table.insert(parts, k .. "=" .. v) end
            return table.concat(parts, "&")
        end,
    }

    mock_kong = {
        response = {
            exit_called = false,
            exit_args = {},
            exit = function(status, body)
                mock_kong.response.exit_called = true
                mock_kong.response.exit_args = { status = status, body = body }
                error("kong.response.exit called")
            end,
        },
        ctx = {
            shared = {},
        },
        log = {
            err = function(...) end,
            debug = function(...) end,
        },
    }

    -- Inject mocks
    _G.kong = mock_kong
    package.loaded["resty.http"] = { new = function() return mock_http_client end }
    package.loaded["ngx.timer"] = { at = function(delay, cb) cb() return true, nil end } -- Simulate immediate timer execution
end

local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(ok or string.find(err, "kong.response.exit called"), "Test should either pass or simulate Kong exit")
end

-- --- Test Suite ---

describe("service-callout handler", function()

    before_each(reset_mocks)

    it("Scenario 1: should perform a synchronous GET and store the response", function()
        local conf = {
            url = "http://example.com/api/data",
            method = "GET",
            timeout = 5000,
            output_variable_name = "callout_result",
            query_params = { key = "value" },
        }

        local instance = ServiceCalloutHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.falsy(mock_kong.response.exit_called, "Should not exit on success")
        assert.are.equal(5000, mock_http_client.set_timeout_called_with)
        assert.string.matches(mock_http_client.request_uri_called_with.uri, "http://example.com/api/data?key=value")
        assert.is_not_nil(mock_kong.ctx.shared.callout_result, "Response should be stored in shared context")
        assert.are.equal(200, mock_kong.ctx.shared.callout_result.status)
        assert.are.equal('{"data":"mock_response"}', mock_kong.ctx.shared.callout_result.body)
    end)

    it("Scenario 2: should handle a callout failure and exit", function()
        local conf = { url = "http://example.com", method = "GET", on_error_continue = false }
        mock_http_client.should_error = true

        local instance = ServiceCalloutHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.truthy(mock_kong.response.exit_called, "Should exit on callout failure")
        assert.are.equal(503, mock_kong.response.exit_args.status)
        assert.string.matches(mock_kong.response.exit_args.body.message, "Service callout failed")
    end)

    it("Scenario 3: should run in fire-and-forget mode without blocking", function()
        local conf = { url = "http://example.com/log", method = "POST", fire_and_forget = true }
        local instance = ServiceCalloutHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.falsy(mock_kong.response.exit_called, "Should not exit in fire-and-forget mode")
        assert.is_nil(mock_kong.ctx.shared.callout_result, "No response should be stored in fire-and-forget mode")
    end)
end)