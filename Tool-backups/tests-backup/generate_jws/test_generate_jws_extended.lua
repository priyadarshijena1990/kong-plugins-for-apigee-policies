-- Extended functional and unit tests for the generate-jws plugin

local handler_module = require("kong.plugins.generate-jws.handler")
local GenerateJWSHandler = handler_module -- The module itself is the handler class
local cjson = require "cjson"

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        request = {
            get_header = function(...) return nil end,
            get_query_arg = function(...) return nil end,
            get_raw_body = function(...) return nil end,
            set_header = function(...) mock_kong.request.set_header_called = true; mock_kong.request.set_header_args = {...} end,
            set_query_arg = function(...) mock_kong.request.set_query_arg_called = true; mock_kong.request.set_query_arg_args = {...} end,
            set_body = function(...) mock_kong.request.set_body_called = true; mock_kong.request.set_body_args = {...} end,
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
                    return { status = 200, body = cjson.encode({ jws = "generated.mock.jws.string" }) }, nil
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
    local instance = GenerateJWSHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == GenerateJWSHandler, "Instance should have correct metatable")
end

-- --- Scenario 1: Successful JWS generation and placement (header destination). ---
do
    reset_mock_kong()
    local conf = {
        jws_generate_service_url = "http://mock-jws-service.com/generate",
        payload_source_type = "literal",
        payload_source_name = "My Payload",
        private_key_source_type = "literal",
        private_key_literal = "MOCK_PRIVATE_KEY_LITERAL",
        algorithm = "HS256",
        jws_header_parameters = { typ = "JWT" },
        output_destination_type = "header",
        output_destination_name = "X-Generated-JWS",
        on_error_continue = false,
    }
    local instance = GenerateJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on successful JWS generation")
    assert(mock_kong.request.set_header_called, "kong.request.set_header should be called")
    assert(mock_kong.request.set_header_args[1] == "X-Generated-JWS", "Header name should match")
    assert(mock_kong.request.set_header_args[2] == "generated.mock.jws.string", "Generated JWS should be set in header")
end

-- --- Scenario 2: Payload not found (header source, on_error_continue = false). ---
do
    reset_mock_kong()
    local conf = {
        jws_generate_service_url = "http://mock-jws-service.com/generate",
        payload_source_type = "header",
        payload_source_name = "X-Missing-Payload",
        private_key_source_type = "literal",
        private_key_literal = "KEY",
        algorithm = "HS256",
        output_destination_type = "header",
        output_destination_name = "X-Generated-JWS",
        on_error_status = 400, on_error_body = "Missing Payload", on_error_continue = false,
    }
    -- mock_kong.request.get_header for X-Missing-Payload will return nil by default
    local instance = GenerateJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit when payload not found")
    assert(mock_kong.response.exit_args.status == 400, "Should return configured error status")
    assert(mock_kong.log.err_called, "Error should be logged for missing payload")
    assert(string.find(mock_kong.log.err_args[1], "No payload content found from source"), "Error message should indicate missing payload")
end

-- --- Scenario 3: Private key not found (shared_context source, on_error_continue = false). ---
do
    reset_mock_kong()
    local conf = {
        jws_generate_service_url = "http://mock-jws-service.com/generate",
        payload_source_type = "literal", payload_source_name = "Payload",
        private_key_source_type = "shared_context", private_key_source_name = "missing_private_key",
        algorithm = "HS256",
        output_destination_type = "header", output_destination_name = "X-Generated-JWS",
        on_error_status = 500, on_error_body = "Missing Private Key", on_error_continue = false,
    }
    -- mock_kong.ctx.shared["missing_private_key"] will be nil by default
    local instance = GenerateJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit when private key not found")
    assert(mock_kong.response.exit_args.status == 500, "Should return configured error status")
    assert(mock_kong.log.err_called, "Error should be logged for missing private key")
    assert(string.find(mock_kong.log.err_args[1], "No private key found from source"), "Error message should indicate missing private key")
end

-- --- Scenario 4: External service call network failure (on_error_continue = false). ---
do
    reset_mock_kong()
    local conf = {
        jws_generate_service_url = "http://mock-jws-service.com/generate",
        payload_source_type = "literal", payload_source_name = "Payload",
        private_key_source_type = "literal", private_key_literal = "KEY",
        algorithm = "HS256",
        output_destination_type = "header", output_destination_name = "X-Generated-JWS",
        on_error_status = 502, on_error_body = "Generator Service Down", on_error_continue = false,
    }
    mock_kong.http.client.go = function(...) return nil, "connection refused" end -- Simulate network error

    local instance = GenerateJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit on service network failure")
    assert(mock_kong.response.exit_args.status == 502, "Status should match config")
    assert(mock_kong.log.err_called, "Error should be logged for service call failure")
    assert(string.find(mock_kong.log.err_args[1], "Call to JWS generate service .* failed"), "Error message should match")
end

-- --- Scenario 5: External service returns non-200 status (on_error_continue = true). ---
do
    reset_mock_kong()
    local conf = {
        jws_generate_service_url = "http://mock-jws-service.com/generate",
        payload_source_type = "literal", payload_source_name = "Payload",
        private_key_source_type = "literal", private_key_literal = "KEY",
        algorithm = "HS256",
        output_destination_type = "header", output_destination_name = "X-Generated-JWS",
        on_error_continue = true,
    }
    mock_kong.http.client.go = function(...) return { status = 401, body = "Invalid Key" }, nil end -- Simulate non-200

    local instance = GenerateJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on non-200 from service when on_error_continue is true")
    assert(mock_kong.log.err_called, "Error should be logged for non-200 service response")
    assert(string.find(mock_kong.log.err_args[1], "JWS generate service .* returned error status: 401"), "Error message should match")
    assert(mock_kong.request.set_header_called == nil, "JWS should not be set on error")
end

-- --- Scenario 6: Different payload_source_type (body with JSON path). ---
do
    reset_mock_kong()
    local conf = {
        jws_generate_service_url = "http://mock-jws-service.com/generate",
        payload_source_type = "body",
        payload_source_name = "data.message",
        private_key_source_type = "literal", private_key_literal = "KEY",
        algorithm = "HS256",
        output_destination_type = "shared_context", output_destination_name = "generated_jws",
        on_error_continue = false,
    }
    local original_body = cjson.encode({ data = { message = "Hello, JWS!" } })
    mock_kong.request.get_raw_body = function() return original_body end
    mock_kong.http.client.go = function(url, opts)
        local request_payload = cjson.decode(opts.body).payload
        assert(request_payload == "Hello, JWS!", "External service should receive payload from JSON path")
        return { status = 200, body = cjson.encode({ jws = "jws.from.body.path" }) }, nil
    end

    local instance = GenerateJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.ctx.shared["generated_jws"] == "jws.from.body.path", "Generated JWS should be in shared context")
end

-- --- Scenario 7: Different output_destination_type (body with JSON path). ---
do
    reset_mock_kong()
    local conf = {
        jws_generate_service_url = "http://mock-jws-service.com/generate",
        payload_source_type = "literal", payload_source_name = "SomeData",
        private_key_source_type = "literal", private_key_literal = "KEY",
        algorithm = "HS256",
        output_destination_type = "body",
        output_destination_name = "response.token",
        on_error_continue = false,
    }
    local original_request_body = cjson.encode({ request = { id = "123" } })
    mock_kong.request.get_raw_body = function() return original_request_body end -- For set_value_to_destination to read

    local instance = GenerateJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.request.set_body_called, "kong.request.set_body should be called")
    local updated_body = cjson.decode(mock_kong.request.set_body_args[1])
    assert(updated_body.response.token == "generated.mock.jws.string", "JWS should be inserted into body JSON path")
    assert(updated_body.request.id == "123", "Other body content should be preserved")
    assert(mock_kong.request.set_header_args[1] == "Content-Type" and mock_kong.request.set_header_args[2] == "application/json", "Content-Type should be set to application/json")
end

-- --- Scenario 8: Replacing entire request body with JWS. ---
do
    reset_mock_kong()
    local conf = {
        jws_generate_service_url = "http://mock-jws-service.com/generate",
        payload_source_type = "literal", payload_source_name = "SomeData",
        private_key_source_type = "literal", private_key_literal = "KEY",
        algorithm = "HS256",
        output_destination_type = "body",
        output_destination_name = ".", -- Replace entire body
        on_error_continue = false,
    }
    local original_request_body = "Any body content"
    mock_kong.request.get_raw_body = function() return original_request_body end

    local instance = GenerateJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.request.set_body_called, "kong.request.set_body should be called")
    assert(mock_kong.request.set_body_args[1] == "generated.mock.jws.string", "Entire body should be replaced with JWS")
    assert(mock_kong.request.set_header_args[1] == "Content-Type" and mock_kong.request.set_header_args[2] == "text/plain", "Content-Type should be set to text/plain")
end

-- --- Scenario 9: Correct algorithm and jws_header_parameters sent to external service. ---
do
    reset_mock_kong()
    local conf = {
        jws_generate_service_url = "http://mock-jws-service.com/generate",
        payload_source_type = "literal", payload_source_name = "Payload",
        private_key_source_type = "literal", private_key_literal = "THE_PRIVATE_KEY",
        algorithm = "RS256",
        jws_header_parameters = { kid = "my_key_id", x5t = "certificate_thumbprint" },
        output_destination_type = "shared_context", output_destination_name = "jws_output",
        on_error_continue = false,
    }
    mock_kong.http.client.go = function(url, opts)
        local request_body_table = cjson.decode(opts.body)
        assert(request_body_table.payload == "Payload", "Payload should be sent to service")
        assert(request_body_table.private_key == "THE_PRIVATE_KEY", "Private key should be sent to service")
        assert(request_body_table.algorithm == "RS256", "Algorithm should be sent to service")
        assert(request_body_table.header_parameters.kid == "my_key_id", "kid header param should be sent")
        assert(request_body_table.header_parameters.x5t == "certificate_thumbprint", "x5t header param should be sent")
        return { status = 200, body = cjson.encode({ jws = "custom.header.jws" }) }, nil
    end

    local instance = GenerateJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)
    assert(mock_kong.ctx.shared["jws_output"] == "custom.header.jws", "Generated JWS should be stored")
end


print("All generate-jws extended tests passed!")