-- Extended functional and unit tests for the concurrent-rate-limit plugin

local handler_module = require("kong.plugins.concurrent-rate-limit.handler")
local ConcurrentRateLimitHandler = handler_module -- The module itself is the handler class

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        shared = {
            concurrent_limit_counters = {},
            -- Mock incr method for shared dictionary
            incr = function(self, key, delta)
                self[key] = (self[key] or 0) + delta
                return self[key]
            end,
        },
        request = {
            get_header = function(...) return nil end,
            get_query_arg = function(...) return nil end,
            get_uri = function(...) return nil end,
        },
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
            exit = function(status_code, body)
                mock_kong.response.exit_called = true
                mock_kong.response.exit_args = { status = status_code, body = body }
                error("Kong response exit called") -- Simulate Kong exiting the request
            end,
        },
        -- Mocking super access method as it's called internally
        super = {
          access = function() end,
          log = function() end,
        }
    }
end

-- Helper function to run a test and catch the simulated exit error
local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(not ok and string.find(err, "Kong response exit called") or ok, "Test should either pass or simulate Kong exit")
end


-- Test Scenario 1: Full cycle - increment, exceed, decrement.
do
    reset_mock_kong()
    local conf = {
        rate = 2,
        counter_key_source_type = "header",
        counter_key_source_name = "X-Test-Key",
        on_limit_exceeded_status = 429,
        on_limit_exceeded_body = "Limit Exceeded Test"
    }
    local instance = ConcurrentRateLimitHandler:new()
    local test_key = "user-abc"
    mock_kong.request.get_header = function(name) if name == conf.counter_key_source_name then return test_key end end

    -- Request 1: Should be allowed (count = 1)
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.response.exit_called == false, "Request 1 should not exit")
    assert(mock_kong.shared.concurrent_limit_counters[test_key] == 1, "Counter should be 1 after Request 1")

    -- Request 2: Should be allowed (count = 2)
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.response.exit_called == false, "Request 2 should not exit")
    assert(mock_kong.shared.concurrent_limit_counters[test_key] == 2, "Counter should be 2 after Request 2")

    -- Reset exit_called for next check
    mock_kong.response.exit_called = false

    -- Request 3: Should exceed limit (count = 3, then decremented to 2) and exit
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.response.exit_called == true, "Request 3 should exit")
    assert(mock_kong.response.exit_args.status == 429, "Exit status should be 429")
    assert(mock_kong.response.exit_args.body == "Limit Exceeded Test", "Exit body should match config")
    -- Counter should be decremented back because this request was rejected
    assert(mock_kong.shared.concurrent_limit_counters[test_key] == 2, "Counter should be 2 after rejected Request 3")
    mock_kong.response.exit_called = false -- Reset for log phase check

    -- Simulate log phase for allowed requests (Request 1 and 2)
    -- This would typically happen after the response is sent for allowed requests.
    -- We need to mock kong.ctx.shared.concurrent_limit_key
    mock_kong.ctx.shared.concurrent_limit_key = test_key

    run_test_and_catch_exit(function() instance:log(conf) end)
    assert(mock_kong.shared.concurrent_limit_counters[test_key] == 1, "Counter should be 1 after first log phase decrement")

    run_test_and_catch_exit(function() instance:log(conf) end)
    assert(mock_kong.shared.concurrent_limit_counters[test_key] == 0, "Counter should be 0 after second log phase decrement")

    assert(mock_kong.response.exit_called == false, "Log phase should not call exit")
end

-- Test Scenario 2: Different counter_key_source_type (query)
do
    reset_mock_kong()
    local conf = {
        rate = 1,
        counter_key_source_type = "query",
        counter_key_source_name = "api_client_id",
        on_limit_exceeded_status = 403,
        on_limit_exceeded_body = "Forbidden"
    }
    local instance = ConcurrentRateLimitHandler:new()
    local client_id = "client-xyz"
    mock_kong.request.get_query_arg = function(name) if name == conf.counter_key_source_name then return client_id end end

    -- Request 1: Allow
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.shared.concurrent_limit_counters[client_id] == 1, "Query key counter should be 1")
    assert(mock_kong.ctx.shared.concurrent_limit_key == client_id, "Key should be stored in shared context")

    -- Request 2: Exceed
    mock_kong.response.exit_called = false
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.response.exit_called == true, "Query key limit should be exceeded")
    assert(mock_kong.response.exit_args.status == 403, "Exit status should be 403")
    assert(mock_kong.shared.concurrent_limit_counters[client_id] == 1, "Query key counter should be 1 after rejection")

    -- Log phase decrement
    mock_kong.ctx.shared.concurrent_limit_key = client_id
    run_test_and_catch_exit(function() instance:log(conf) end)
    assert(mock_kong.shared.concurrent_limit_counters[client_id] == 0, "Query key counter should be 0 after decrement")
end

-- Test Scenario 3: Different counter_key_source_type (path - full URI)
do
    reset_mock_kong()
    local conf = {
        rate = 1,
        counter_key_source_type = "path",
        counter_key_source_name = ".", -- Represents full URI
        on_limit_exceeded_status = 503,
        on_limit_exceeded_body = "Service Unavailable"
    }
    local instance = ConcurrentRateLimitHandler:new()
    local uri = "/my/api/resource"
    mock_kong.request.get_uri = function() return uri end

    -- Request 1: Allow
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.shared.concurrent_limit_counters[uri] == 1, "Path URI key counter should be 1")

    -- Request 2: Exceed
    mock_kong.response.exit_called = false
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.response.exit_called == true, "Path URI key limit should be exceeded")
    assert(mock_kong.response.exit_args.status == 503, "Exit status should be 503")
end

-- Test Scenario 4: Different counter_key_source_type (shared_context)
do
    reset_mock_kong()
    local conf = {
        rate = 1,
        counter_key_source_type = "shared_context",
        counter_key_source_name = "session_id",
        on_limit_exceeded_status = 429,
        on_limit_exceeded_body = "Too Many Requests"
    }
    local instance = ConcurrentRateLimitHandler:new()
    local session_id = "sess-123"
    mock_kong.ctx.shared.session_id = session_id -- Set in shared context

    -- Request 1: Allow
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.shared.concurrent_limit_counters[session_id] == 1, "Shared context key counter should be 1")

    -- Request 2: Exceed
    mock_kong.response.exit_called = false
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.response.exit_called == true, "Shared context key limit should be exceeded")
end

-- Test Scenario 5: Shared dictionary 'concurrent_limit_counters' is not configured.
do
    reset_mock_kong()
    mock_kong.shared.concurrent_limit_counters = nil -- Simulate unconfigured shared dict
    local conf = {
        rate = 1,
        counter_key_source_type = "header",
        counter_key_source_name = "X-User"
    }
    local instance = ConcurrentRateLimitHandler:new()
    mock_kong.request.get_header = function(...) return "someuser" end

    -- Access phase
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.log.err_called, "Error should be logged for unconfigured shared dict (access phase)")
    assert(string.find(mock_kong.log.err_args[1], "Shared dictionary 'concurrent_limit_counters' is not configured"), "Error message should match")
    assert(mock_kong.response.exit_called == false, "Request should proceed if shared dict is unconfigured")
    
    mock_kong.log.err_called = false -- Reset for log phase

    -- Log phase
    mock_kong.ctx.shared.concurrent_limit_key = "someuser" -- Key might be set from other plugins or logic
    run_test_and_catch_exit(function() instance:log(conf) end)
    assert(mock_kong.log.err_called, "Error should be logged for unconfigured shared dict (log phase)")
    assert(string.find(mock_kong.log.err_args[1], "Shared dictionary 'concurrent_limit_counters' is not configured"), "Error message should match")
end

-- Test Scenario 6: Error during counters:incr (access phase).
do
    reset_mock_kong()
    mock_kong.shared.concurrent_limit_counters.incr = function(self, key, delta)
        return nil, "mock incr error" -- Simulate error
    end
    local conf = {
        rate = 1,
        counter_key_source_type = "header",
        counter_key_source_name = "X-User"
    }
    local instance = ConcurrentRateLimitHandler:new()
    mock_kong.request.get_header = function(...) return "someuser" end

    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.log.err_called, "Error should be logged for incr failure (access phase)")
    assert(string.find(mock_kong.log.err_args[1], "Failed to increment counter"), "Error message should match")
    assert(mock_kong.response.exit_called == false, "Request should proceed if incr fails")
end

-- Test Scenario 7: `log` phase with no `concurrent_limit_key` in `kong.ctx.shared`.
do
    reset_mock_kong()
    local conf = { rate = 1 } -- Conf doesn't matter much for this specific log phase test
    local instance = ConcurrentRateLimitHandler:new()
    mock_kong.ctx.shared.concurrent_limit_key = nil -- Simulate missing key

    run_test_and_catch_exit(function() instance:log(conf) end)
    assert(mock_kong.log.warn_called, "Warning should be logged for missing concurrent_limit_key (log phase)")
    assert(string.find(mock_kong.log.warn_args[1], "No 'concurrent_limit_key' found in shared context"), "Warning message should match")
end

-- Test Scenario 8: `log` phase with error during `counters:incr` (decrement).
do
    reset_mock_kong()
    mock_kong.shared.concurrent_limit_counters.incr = function(self, key, delta)
        if delta == -1 then return nil, "mock decr error" end -- Simulate error only on decrement
        self[key] = (self[key] or 0) + delta
        return self[key]
    end
    local conf = { rate = 1 }
    local instance = ConcurrentRateLimitHandler:new()
    mock_kong.ctx.shared.concurrent_limit_key = "somekey" -- Assume key was set

    run_test_and_catch_exit(function() instance:log(conf) end)
    assert(mock_kong.log.err_called, "Error should be logged for decr failure (log phase)")
    assert(string.find(mock_kong.log.err_args[1], "Failed to decrement counter"), "Error message should match")
end

print("All concurrent-rate-limit extended tests passed!")