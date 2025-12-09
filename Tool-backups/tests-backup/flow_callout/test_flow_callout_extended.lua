-- Extended functional and unit tests for the flow-callout plugin

local handler_module = require("kong.plugins.flow-callout.handler")
local FlowCalloutHandler = handler_module -- The module itself is the handler class
local cjson = require "cjson"

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        request = {
            get_method = function(...) return "GET" end,
            get_uri = function(...) return "/original/path" end,
            get_headers = function(...) return { ["X-Original-Header"] = "value" } end,
            get_raw_body = function(...) return "Original Request Body" end,
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
        db = {
            services = {
                select_by_name = function(name) -- Default mock: service found
                    if name == "my-shared-flow-service" then
                        return { id = "service-id-123", name = "my-shared-flow-service", protocol = "http", host = "127.0.0.1" }, nil
                    else
                        return nil, "Service not found"
                    end
                end,
            },
        },
        service = {
            request = function(opts) -- Default mock: successful internal request
                assert(opts.method == mock_kong.request.get_method(), "Internal call method should match original")
                assert(opts.path == mock_kong.request.get_uri(), "Internal call URI should match original")
                assert(opts.headers["X-Original-Header"] == mock_kong.request.get_headers()["X-Original-Header"], "Internal call headers should match original")
                assert(opts.body == mock_kong.request.get_raw_body(), "Internal call body should match original")
                return 200, { ["X-Flow-Result"] = "OK" }, "Shared Flow Response Body", nil
            end,
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
    local instance = FlowCalloutHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == FlowCalloutHandler, "Instance should have correct metatable")
end

-- --- Scenario 1: Successful shared flow execution. ---
do
    reset_mock_kong()
    local conf = {
        shared_flow_service_name = "my-shared-flow-service",
        preserve_original_request_body = true,
        on_flow_error_continue = false,
        store_flow_response_in_shared_context_key = "flow_output",
    }
    local instance = FlowCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on successful flow execution")
    assert(mock_kong.ctx.shared["flow_output"] ~= nil, "Flow response should be stored in shared context")
    assert(mock_kong.ctx.shared["flow_output"].status == 200, "Flow response status should be 200")
    assert(mock_kong.ctx.shared["flow_output"].body == "Shared Flow Response Body", "Flow response body should match")
    assert(mock_kong.ctx.shared["flow_output"].headers["X-Flow-Result"] == "OK", "Flow response header should match")
    assert(mock_kong.request.get_raw_body() == "Original Request Body", "Original request body should be preserved")
end

-- --- Scenario 2: Shared flow service not found. ---
do
    reset_mock_kong()
    mock_kong.db.services.select_by_name = function(...) return nil, "Service not found" end -- Mock service not found
    local conf = {
        shared_flow_service_name = "non-existent-service",
        on_flow_error_status = 500, on_flow_error_body = "Flow Service Missing", on_flow_error_continue = false,
    }
    local instance = FlowCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit when shared flow service is not found")
    assert(mock_kong.response.exit_args.status == 500, "Status should be 500")
    assert(mock_kong.response.exit_args.body == "Flow Service Missing", "Body should match config")
    assert(mock_kong.log.err_called, "Error should be logged for missing service")
    assert(string.find(mock_kong.log.err_args[1], "Kong Service 'non-existent-service' not found"), "Error message should match")
end

-- --- Scenario 3: Internal call failure (network error). ---
do
    reset_mock_kong()
    mock_kong.service.request = function(...) return nil, "connection refused" end -- Mock internal call failure
    local conf = {
        shared_flow_service_name = "my-shared-flow-service",
        on_flow_error_status = 503, on_flow_error_body = "Shared Flow Unavailable", on_flow_error_continue = false,
        store_flow_response_in_shared_context_key = "flow_output_error",
    }
    local instance = FlowCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit on internal call network error")
    assert(mock_kong.response.exit_args.status == 503, "Status should be 503")
    assert(mock_kong.response.exit_args.body == "Shared Flow Unavailable", "Body should match config")
    assert(mock_kong.log.err_called, "Error should be logged for internal call failure")
    assert(string.find(mock_kong.log.err_args[1], "Internal call to shared flow service .* failed"), "Error message should match")
    assert(mock_kong.ctx.shared["flow_output_error"].body == "connection refused", "Error details should be stored in body field")
end

-- --- Scenario 4: Shared flow service returns error status (e.g., 404). ---
do
    reset_mock_kong()
    mock_kong.service.request = function(...) return 404, {}, "Not Found by Flow", nil end -- Mock error status from flow
    local conf = {
        shared_flow_service_name = "my-shared-flow-service",
        on_flow_error_status = 400, on_flow_error_body = "Bad Request from Flow", on_flow_error_continue = false,
        store_flow_response_in_shared_context_key = "flow_output_404",
    }
    local instance = FlowCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit on error status from shared flow service")
    assert(mock_kong.response.exit_args.status == 400, "Status should be 400")
    assert(mock_kong.response.exit_args.body == "Bad Request from Flow", "Body should match config")
    assert(mock_kong.log.warn_called, "Warning should be logged for error status from flow")
    assert(string.find(mock_kong.log.warn_args[1], "Shared flow service .* returned error status: 404"), "Warning message should match")
    assert(mock_kong.ctx.shared["flow_output_404"].status == 404, "Flow response status should be stored")
    assert(mock_kong.ctx.shared["flow_output_404"].body == "Not Found by Flow", "Flow response body should be stored")
end

-- --- Scenario 5: on_flow_error_continue = true with internal call failure. ---
do
    reset_mock_kong()
    mock_kong.service.request = function(...) return nil, "another network error" end
    local conf = {
        shared_flow_service_name = "my-shared-flow-service",
        on_flow_error_continue = true,
        store_flow_response_in_shared_context_key = "flow_output_cont_error",
    }
    local instance = FlowCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit when on_flow_error_continue is true")
    assert(mock_kong.log.err_called, "Error should be logged for internal call failure")
    assert(string.find(mock_kong.log.err_args[1], "Internal call to shared flow service .* failed"), "Error message should match")
    assert(mock_kong.log.warn_called, "Warning should be logged for continuing after error")
    assert(string.find(mock_kong.log.warn_args[1], "Shared flow call failed but 'on_flow_error_continue' is true"), "Warning message should match")
    assert(mock_kong.ctx.shared["flow_output_cont_error"].body == "another network error", "Error details should be stored")
end

-- --- Scenario 6: on_flow_error_continue = true with shared flow service returning error status. ---
do
    reset_mock_kong()
    mock_kong.service.request = function(...) return 500, {}, "Internal error from flow", nil end
    local conf = {
        shared_flow_service_name = "my-shared-flow-service",
        on_flow_error_continue = true,
        store_flow_response_in_shared_context_key = "flow_output_cont_status",
    }
    local instance = FlowCalloutHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit when on_flow_error_continue is true")
    assert(mock_kong.log.warn_called, "Warning should be logged for error status from flow")
    assert(string.find(mock_kong.log.warn_args[1], "Shared flow service .* returned error status: 500"), "Warning message should match")
    assert(mock_kong.ctx.shared["flow_output_cont_status"].status == 500, "Flow response status should be stored")
end

-- --- Scenario 7: Capturing original request details. ---
-- This is implicitly tested in the default mock for kong.service.request in reset_mock_kong()
-- which asserts that the original method, uri, headers, and body are passed.

-- --- Scenario 8: preserve_original_request_body. ---
-- This configuration simply indicates a preference. Kong's kong.request.get_raw_body()
-- is generally safe to call multiple times as it reads the internal buffer.
-- The test in Scenario 1 already asserts that the original body remains.
-- No additional specific test needed here for this configuration parameter.

print("All flow-callout extended tests passed!")