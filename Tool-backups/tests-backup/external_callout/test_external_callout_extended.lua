-- Extended functional and unit tests for the external-callout plugin

local handler_module = require("kong.plugins.external-callout.handler")
local ExternalCalloutHandler = handler_module -- The module itself is the handler class
local cjson = require "cjson"

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        request = {
            get_raw_body = function(...) return nil end,
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
            exit = function(args)
                mock_kong.response.exit_called = true
                mock_kong.response.exit_args = args
                error("Kong response exit called") -- Simulate Kong exiting the request
            end,
        },
        http = {
            client = {
                go = function(...) -- Default mock: success
                    return { status = 200, headers = { ["X-Test-Response"] = "OK" }, body = "External Service Success" }, nil
                end,
            },
        },
        -- Mocking super access method as it's called internally
        super = {
          access = function() end,
        }
    }
end

-- Helper function to run a test and catch the simulated exit error
local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(not ok and string.find(err, "Kong response exit called") or ok, "Test should either pass or simulate Kong exit")
end

-- --- Unit Test: new() method ---
do
    reset_mock_kong()
    local instance = ExternalCalloutHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == ExternalCalloutHandler, "Instance should have correct metatable")
end

-- --- Scenario 1: Successful callout with wait_for_response = true. ---
do
    reset_mock_kong()
    local conf = {
        callout_url = "http://example.com/callback",
        method = "POST",
        request_body_source_type = "none",
        wait_for_response = true,
        response_to_shared_context_key = "external_response",
        on_error_continue = false,
    }
    local instance = ExternalCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on successful callout")
    assert(mock_kong.ctx.shared["external_response"] ~= nil, "Response should be stored in shared context")
    assert(mock_kong.ctx.shared["external_response"].status == 200, "Response status should be 200")
    assert(mock_kong.ctx.shared["external_response"].body == "External Service Success", "Response body should match")
    assert(mock_kong.ctx.shared["external_response"].headers["X-Test-Response"] == "OK", "Response header should match")
end

-- --- Scenario 2: Callout with different methods and headers (GET). ---
do
    reset_mock_kong()
    local conf = {
        callout_url = "http://example.com/info",
        method = "GET",
        headers = { ["X-Request-ID"] = "12345" },
        request_body_source_type = "none",
        wait_for_response = true,
        response_to_shared_context_key = "external_info",
    }
    mock_kong.http.client.go = function(url, opts)
        assert(url == conf.callout_url, "URL should match config")
        assert(opts.method == "GET", "Method should be GET")
        assert(opts.headers["X-Request-ID"] == "12345", "Custom header should be sent")
        return { status = 200, body = "Info Received" }, nil
    end

    local instance = ExternalCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.ctx.shared["external_info"].body == "Info Received", "Info should be received")
end

-- --- Scenario 3: request_body_source_type = "request_body". ---
do
    reset_mock_kong()
    local conf = {
        callout_url = "http://example.com/process", method = "POST",
        request_body_source_type = "request_body", wait_for_response = true,
    }
    local original_request_body = "Original Request Data"
    mock_kong.request.get_raw_body = function() return original_request_body end
    mock_kong.http.client.go = function(url, opts)
        assert(opts.body == original_request_body, "Original request body should be sent")
        return { status = 200, body = "Processed" }, nil
    end

    local instance = ExternalCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)
end

-- --- Scenario 4: request_body_source_type = "shared_context" (string value). ---
do
    reset_mock_kong()
    local conf = {
        callout_url = "http://example.com/shared", method = "POST",
        request_body_source_type = "shared_context", request_body_source_name = "data_from_ctx",
        wait_for_response = true,
    }
    local shared_string = "Data from shared context"
    mock_kong.ctx.shared.data_from_ctx = shared_string
    mock_kong.http.client.go = function(url, opts)
        assert(opts.body == shared_string, "Shared context string should be sent")
        return { status = 200, body = "Processed Shared" }, nil
    end

    local instance = ExternalCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)
end

-- --- Scenario 5: request_body_source_type = "shared_context" (table value). ---
do
    reset_mock_kong()
    local conf = {
        callout_url = "http://example.com/shared-json", method = "POST",
        request_body_source_type = "shared_context", request_body_source_name = "json_from_ctx",
        wait_for_response = true,
    }
    local shared_table = { user = "test", id = 123 }
    mock_kong.ctx.shared.json_from_ctx = shared_table
    mock_kong.http.client.go = function(url, opts)
        assert(opts.body == cjson.encode(shared_table), "Shared context table should be JSON encoded and sent")
        return { status = 200, body = "Processed JSON Shared" }, nil
    end

    local instance = ExternalCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)
end

-- --- Scenario 6: request_body_source_type = "none". ---
do
    reset_mock_kong()
    local conf = {
        callout_url = "http://example.com/ping", method = "GET",
        request_body_source_type = "none", wait_for_response = true,
    }
    mock_kong.http.client.go = function(url, opts)
        assert(opts.body == nil, "No body should be sent")
        return { status = 200, body = "Pong" }, nil
    end

    local instance = ExternalCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)
end

-- --- Scenario 7: wait_for_response = false (fire and forget). ---
do
    reset_mock_kong()
    local call_count = 0
    local conf = {
        callout_url = "http://example.com/notify", method = "POST",
        request_body_source_type = "none", wait_for_response = false,
        response_to_shared_context_key = "should_not_be_set",
    }
    mock_kong.http.client.go = function(...) call_count = call_count + 1; return nil, "network error" end -- Simulate failure but should not block
    local instance = ExternalCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit for fire and forget even on error")
    assert(call_count == 1, "External call should be initiated")
    assert(mock_kong.ctx.shared["should_not_be_set"] == nil, "Response should not be stored")
    assert(mock_kong.log.debug_called, "Debug log for fire-and-forget should be called")
end

-- --- Scenario 8: Callout failure (network error) with on_error_continue = false. ---
do
    reset_mock_kong()
    local conf = {
        callout_url = "http://example.com/critical", method = "GET",
        request_body_source_type = "none", wait_for_response = true,
        on_error_status = 503, on_error_body = "Service Unavailable", on_error_continue = false,
    }
    mock_kong.http.client.go = function(...) return nil, "connection timed out" end

    local instance = ExternalCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit on network error when on_error_continue is false")
    assert(mock_kong.response.exit_args.status == 503, "Status should match config")
    assert(mock_kong.log.err_called, "Error should be logged for network failure")
    assert(string.find(mock_kong.log.err_args[1], "Call to external service .* failed: connection timed out"), "Error message should match")
end

-- --- Scenario 9: Callout failure (non-2xx status) with on_error_continue = true. ---
do
    reset_mock_kong()
    local conf = {
        callout_url = "http://example.com/optional", method = "GET",
        request_body_source_type = "none", wait_for_response = true,
        on_error_status = 500, on_error_body = "Internal Error", on_error_continue = true,
        response_to_shared_context_key = "optional_response",
    }
    mock_kong.http.client.go = function(...) return { status = 401, body = "Auth Failed" }, nil end

    local instance = ExternalCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on non-2xx when on_error_continue is true")
    assert(mock_kong.log.warn_called, "Warning should be logged for non-2xx status")
    assert(string.find(mock_kong.log.warn_args[1], "External service .* returned error status: 401"), "Warning message should match")
    assert(mock_kong.ctx.shared["optional_response"].status == 401, "Response should still be stored")
end

-- --- Scenario 10: Error: request_body_source_type = "shared_context" but request_body_source_name is missing. ---
do
    reset_mock_kong()
    local conf = {
        callout_url = "http://example.com/bad-config", method = "POST",
        request_body_source_type = "shared_context", -- request_body_source_name is missing
        wait_for_response = true,
        on_error_status = 500, on_error_body = "Internal Server Error", on_error_continue = false,
    }
    local instance = ExternalCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit when request_body_source_name is missing for shared_context type")
    assert(mock_kong.response.exit_args.status == 500, "Status should be 500")
    assert(mock_kong.log.err_called, "Error should be logged for missing source name")
    assert(string.find(mock_kong.log.err_args[1], "'request_body_source_name' is required"), "Error message should match")
end

print("All external-callout extended tests passed!")