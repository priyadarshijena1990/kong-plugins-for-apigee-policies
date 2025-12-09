-- Unit tests for the assert-condition plugin

local handler_module = require("kong.plugins.assert-condition.handler")
local AssertConditionHandler = handler_module

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        request = {
            get_header = function(...) return nil end,
            get_query_arg = function(...) return nil end,
            get_path = function(...) return nil end,
        },
        client = {
            get_ip = function() return nil end,
        },
        ctx = {
            shared = {},
        },
        log = {
            err_called = false,
            warn_called = false,
            debug_called = false,
            err_args = nil,
            warn_args = nil,
            debug_args = nil,
            err = function(...) mock_kong.log.err_called = true; mock_kong.log.err_args = {...} end,
            warn = function(...) mock_kong.log.warn_called = true; mock_kong.log.warn_args = {...} end,
            debug = function(...) mock_kong.log.debug_called = true; mock_kong.log.debug_args = {...} end,
        },
        response = {
            exit_called = false,
            exit_args = {},
            exit = function(status_code, body)
                mock_kong.response.exit_called = true
                mock_kong.response.exit_args = { status = status_code, body = body }
                error("Kong response exit called") -- Simulate Kong exiting the request
            end,
        },
        -- Mocking super access method as it's called internally
        super = {
          access = function() end,
        },
        service = {}, -- Placeholder for sandbox access
        router = {},  -- Placeholder for sandbox access
    }
end

-- Helper function to run a test and catch the simulated exit error
local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(not ok and string.find(err, "Kong response exit called") or ok, "Test should either pass or simulate Kong exit, or have a controlled error")
end

-- --- Test: new() method (basic instance creation) ---
do
    reset_mock_kong()
    local instance = AssertConditionHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == AssertConditionHandler, "Instance should have correct metatable")
end

-- --- Scenario 1: Condition evaluates to true (continue normally) ---
do
    reset_mock_kong()
    local conf = {
        condition = "true",
        on_false_action = "abort", -- Should not trigger abort
        abort_status = 403,
        abort_message = "Blocked",
        on_error_continue = false,
    }
    
    local instance = AssertConditionHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit when condition is true")
    assert(mock_kong.log.debug_called, "Debug log for true condition should be present")
    assert(string.find(mock_kong.log.debug_args[1], "Condition evaluated to true"), "Debug message should confirm true condition")
    assert(mock_kong.log.err_called == false, "No error should be logged")
end

-- --- Scenario 2: Condition evaluates to false and on_false_action is abort ---
do
    reset_mock_kong()
    local conf = {
        condition = "false",
        on_false_action = "abort",
        abort_status = 403,
        abort_message = "Blocked by condition",
        on_error_continue = false,
    }
    
    local instance = AssertConditionHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == true, "Should exit when condition is false and action is abort")
    assert(mock_kong.response.exit_args.status == conf.abort_status, "Exit status should match configured abort_status")
    assert(mock_kong.response.exit_args.body.message == conf.abort_message, "Exit message should match configured abort_message")
    assert(mock_kong.log.debug_called, "Debug log for false condition should be present")
    assert(string.find(mock_kong.log.debug_args[1], "Condition evaluated to false"), "Debug message should confirm false condition")
    assert(mock_kong.log.err_called == false, "No error should be logged")
end

-- --- Scenario 3: Condition evaluates to false and on_false_action is continue ---
do
    reset_mock_kong()
    local conf = {
        condition = "1 == 2", -- false
        on_false_action = "continue",
        abort_status = 400,
        abort_message = "Ignored",
        on_error_continue = false,
    }
    
    local instance = AssertConditionHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit when condition is false and action is continue")
    assert(mock_kong.log.debug_called, "Debug log for false condition should be present")
    assert(string.find(mock_kong.log.debug_args[1], "Condition evaluated to false"), "Debug message should confirm false condition")
    assert(mock_kong.log.err_called == false, "No error should be logged")
end

-- --- Scenario 4: Error during condition evaluation and on_error_continue is false (default) ---
do
    reset_mock_kong()
    local conf = {
        condition = "not_a_valid_lua_syntax + 1", -- Invalid Lua
        on_false_action = "abort",
        abort_status = 400,
        abort_message = "N/A",
        on_error_continue = false,
    }
    
    local instance = AssertConditionHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == true, "Should exit on error when on_error_continue is false")
    assert(mock_kong.response.exit_args.status == 500, "Exit status should be 500 for internal error")
    assert(string.find(mock_kong.response.exit_args.body.message, "Error evaluating condition"), "Exit message should indicate condition evaluation error")
    assert(mock_kong.log.err_called, "Error should be logged for condition evaluation failure")
    assert(string.find(mock_kong.log.err_args[1], "Error during condition evaluation"), "Error log should indicate condition evaluation failure")
end

-- --- Scenario 5: Error during condition evaluation and on_error_continue is true ---
do
    reset_mock_kong()
    local conf = {
        condition = "local a = ;", -- Invalid Lua syntax
        on_false_action = "abort",
        abort_status = 400,
        abort_message = "N/A",
        on_error_continue = true,
    }
    
    local instance = AssertConditionHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on error when on_error_continue is true")
    assert(mock_kong.log.err_called, "Error should be logged for condition evaluation failure")
    assert(string.find(mock_kong.log.err_args[1], "Error during condition evaluation"), "Error log should indicate condition evaluation failure")
end

-- --- Scenario 6: Condition using kong.request functions ---
do
    reset_mock_kong()
    local conf = {
        condition = "kong.request.get_header('X-Auth-Token') == 'valid-token'",
        on_false_action = "abort",
        abort_status = 401,
        abort_message = "Unauthorized",
        on_error_continue = false,
    }
    mock_kong.request.get_header = function(name)
        if name == 'X-Auth-Token' then return 'valid-token' end
    end
    
    local instance = AssertConditionHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit when header condition is true")
    mock_kong.request.get_header = function(name)
        if name == 'X-Auth-Token' then return 'invalid-token' end
    end
    
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.response.exit_called == true, "Should exit when header condition is false")
    assert(mock_kong.response.exit_args.status == 401, "Exit status should be 401")
end

-- --- Scenario 7: Condition using kong.ctx.shared ---
do
    reset_mock_kong()
    mock_kong.ctx.shared.user_role = "admin"
    local conf = {
        condition = "kong.ctx.shared.user_role == 'admin'",
        on_false_action = "abort",
        abort_status = 403,
        abort_message = "Forbidden",
        on_error_continue = false,
    }
    
    local instance = AssertConditionHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit when shared context condition is true")
    
    mock_kong.ctx.shared.user_role = "guest"
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.response.exit_called == true, "Should exit when shared context condition is false")
    assert(mock_kong.response.exit_args.status == 403, "Exit status should be 403")
end


print("All assert-condition unit tests passed successfully!")
