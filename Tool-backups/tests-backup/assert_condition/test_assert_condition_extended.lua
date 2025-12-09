-- Extended functional and unit tests for the assert-condition plugin

local handler_module = require("kong.plugins.assert-condition.handler")
local AssertConditionHandler = handler_module -- The module itself is the handler class

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        ctx = {
            shared = {},
        },
        log = {
            err = function(...) mock_kong.log.err_called = true; mock_kong.log.err_args = {...} end,
            warn = function(...) mock_kong.log.warn_called = true; mock_kong.log.warn_args = {...} end,
            debug = function(...) end, -- Suppress debug logs in tests for cleaner output
        },
        response = {
            exit_called = false,
            exit_args = {},
            exit = function(args)
                mock_kong.response.exit_called = true
                mock_kong.response.exit_args = args
                error("Kong response exit called") -- Simulate Kong exiting the request
            end,
        },
        -- Mocking super access method as it's called internally
        super = {
          access = function() end
        }
    }
end

-- Before each test, reset the mock Kong environment
reset_mock_kong()

-- Helper function to run a test and catch the simulated exit error
local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(not ok and string.find(err, "Kong response exit called") or ok, "Test should either pass or simulate Kong exit")
end


-- Test Scenario 1: Condition evaluates to false with custom status, body, and headers.
do
    reset_mock_kong()
    local conf = {
        lua_condition = "false", -- Directly false
        on_assertion_failure_status = 403,
        on_assertion_failure_body = "Access Denied Custom",
        on_assertion_failure_headers = {
            ["X-Custom-Header"] = "Denied",
            ["Content-Type"] = "text/plain",
        }
    }
    local instance = AssertConditionHandler:new()
    
    run_test_and_catch_exit(function()
        instance:access(conf)
    end)

    assert(mock_kong.response.exit_called, "kong.response.exit should be called")
    assert(mock_kong.response.exit_args.status == 403, "Status should be 403")
    assert(mock_kong.response.exit_args.body == "Access Denied Custom", "Body should be custom message")
    assert(mock_kong.response.exit_args.headers["X-Custom-Header"] == "Denied", "Custom header should be present")
    assert(mock_kong.response.exit_args.headers["Content-Type"] == "text/plain", "Content-Type should be explicitly set")
    assert(mock_kong.log.warn_called, "Warning should be logged for failed condition")
end

-- Test Scenario 2: Condition evaluates to false with custom reason phrase.
do
    reset_mock_kong()
    local conf = {
        lua_condition = "1 == 0", -- A condition that is false
        on_assertion_failure_status = 404,
        on_assertion_failure_body = "Not Found By Policy",
        on_assertion_failure_reason_phrase = "Policy Failure"
    }
    local instance = AssertConditionHandler:new()

    run_test_and_catch_exit(function()
        instance:access(conf)
    end)

    assert(mock_kong.response.exit_called, "kong.response.exit should be called")
    assert(mock_kong.response.exit_args.status == 404, "Status should be 404")
    assert(mock_kong.response.exit_args.reason == "Policy Failure", "Reason phrase should be custom")
    assert(mock_kong.log.warn_called, "Warning should be logged for failed condition")
end

-- Test Scenario 3: lua_condition causes a runtime error during evaluation.
do
    reset_mock_kong()
    local conf = {
        lua_condition = "error('Runtime error!')", -- A condition that causes a runtime error
        on_assertion_failure_status = 400 -- This should be ignored, 500 should be returned
    }
    local instance = AssertConditionHandler:new()

    run_test_and_catch_exit(function()
        instance:access(conf)
    end)

    assert(mock_kong.response.exit_called, "kong.response.exit should be called due to runtime error")
    assert(mock_kong.response.exit_args.status == 500, "Status should be 500 for runtime error")
    assert(mock_kong.log.err_called, "Error should be logged for runtime error")
    assert(string.find(mock_kong.log.err_args[1], "Error evaluating Lua condition"), "Error message should indicate evaluation error")
end

-- Test Scenario 4: Content-Type inference for JSON body.
do
    reset_mock_kong()
    local conf = {
        lua_condition = "false",
        on_assertion_failure_status = 400,
        on_assertion_failure_body = '{"message": "JSON error"}',
        on_assertion_failure_headers = {} -- No Content-Type set
    }
    local instance = AssertConditionHandler:new()

    run_test_and_catch_exit(function()
        instance:access(conf)
    end)

    assert(mock_kong.response.exit_called, "kong.response.exit should be called")
    assert(mock_kong.response.exit_args.headers["Content-Type"] == "application/json", "Content-Type should be inferred as application/json")
end

-- Test Scenario 5: Content-Type inference for plain text body.
do
    reset_mock_kong()
    local conf = {
        lua_condition = "false",
        on_assertion_failure_status = 400,
        on_assertion_failure_body = "Plain text error message",
        on_assertion_failure_headers = {} -- No Content-Type set
    }
    local instance = AssertConditionHandler:new()

    run_test_and_catch_exit(function()
        instance:access(conf)
    end)

    assert(mock_kong.response.exit_called, "kong.response.exit should be called")
    assert(mock_kong.response.exit_args.headers["Content-Type"] == "text/plain", "Content-Type should be inferred as text/plain")
end

-- Test Scenario 6: on_assertion_failure_headers override default Content-Type.
do
    reset_mock_kong()
    local conf = {
        lua_condition = "false",
        on_assertion_failure_status = 400,
        on_assertion_failure_body = '{"message": "JSON error"}', -- Would normally infer JSON
        on_assertion_failure_headers = {
            ["Content-Type"] = "application/xml"
        }
    }
    local instance = AssertConditionHandler:new()

    run_test_and_catch_exit(function()
        instance:access(conf)
    end)

    assert(mock_kong.response.exit_called, "kong.response.exit should be called")
    assert(mock_kong.response.exit_args.headers["Content-Type"] == "application/xml", "Explicit Content-Type should override inference")
end

print("All assert-condition extended tests passed!")
