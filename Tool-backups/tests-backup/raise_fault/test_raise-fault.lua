-- Unit tests for the raise-fault plugin

local handler_module = require("kong.plugins.raise-fault.handler")
local RaiseFaultHandler = handler_module

-- Mock dependencies
local mock_kong = {}

local function reset_mock_kong()
    mock_kong = {
        response = {
            exit_called = false,
            exit_args = {},
            headers = {},
            set_header = function(key, val) mock_kong.response.headers[key] = val end,
            exit = function(status, body)
                mock_kong.response.exit_called = true
                mock_kong.response.exit_args = { status = status, body = body }
                error("kong.response.exit called") -- Simulate Kong's exit behavior
            end,
        },
    }
    -- Inject mock
    _G.kong = mock_kong
end

local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(not ok and string.find(err, "kong.response.exit called"), "Test should simulate Kong exit")
end

-- --- Test Suite ---

describe("raise-fault handler", function()

    before_each(reset_mock_kong)

    it("Scenario 1: should raise a basic fault with status and body", function()
        local conf = {
            status_code = 403,
            fault_body = "Access Forbidden",
            content_type = "text/plain",
        }

        local instance = RaiseFaultHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.truthy(mock_kong.response.exit_called, "kong.response.exit should have been called")
        assert.are.equal(403, mock_kong.response.exit_args.status)
        assert.are.equal("Access Forbidden", mock_kong.response.exit_args.body)
        assert.are.equal("text/plain", mock_kong.response.headers["Content-Type"])
    end)

    it("Scenario 2: should raise a fault with custom headers", function()
        local conf = {
            status_code = 503,
            fault_body = '{"error":"Service Unavailable"}',
            content_type = "application/json",
            headers = {
                ["X-RateLimit-Reset"] = "1678886400",
                ["X-Custom-Error"] = "E1234",
            }
        }

        local instance = RaiseFaultHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.truthy(mock_kong.response.exit_called)
        assert.are.equal(503, mock_kong.response.exit_args.status)
        assert.are.equal('{"error":"Service Unavailable"}', mock_kong.response.exit_args.body)
        assert.are.equal("application/json", mock_kong.response.headers["Content-Type"])
        assert.are.equal("1678886400", mock_kong.response.headers["X-RateLimit-Reset"])
        assert.are.equal("E1234", mock_kong.response.headers["X-Custom-Error"])
    end)

    it("Scenario 3: should raise a fault with default body and content-type", function()
        local conf = {
            status_code = 400,
            fault_body = "", -- Empty, should be default
            content_type = "text/plain; charset=utf-8", -- Default
        }

        local instance = RaiseFaultHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.truthy(mock_kong.response.exit_called)
        assert.are.equal(400, mock_kong.response.exit_args.status)
        assert.are.equal("", mock_kong.response.exit_args.body)
        assert.are.equal("text/plain; charset=utf-8", mock_kong.response.headers["Content-Type"])
    end)
end)