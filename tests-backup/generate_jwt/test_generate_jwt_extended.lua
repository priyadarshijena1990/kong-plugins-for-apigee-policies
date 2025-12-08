-- Extended functional and unit tests for the generate-jwt plugin

local handler_module = require("kong.plugins.generate-jwt.handler")
local GenerateJWTHandler = handler_module -- The module itself is the handler class
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
                    return { status = 200, body = cjson.encode({ jwt = "generated.mock.jwt.string" }) }, nil
                end,
            },
        },
        -- Mocking super access method as it's called internally
        super = {
          access = function() end,
        }
    }
end

-- Mock ngx.time() for testing 'exp' claim
local MOCK_NGX_TIME = 1678886400 -- March 15, 2023 12:00:00 PM GMT
local original_ngx_time = ngx and ngx.time or function() return os.time() end -- Store original if exists
ngx = ngx or {} -- Ensure ngx table exists
ngx.time = function() return MOCK_NGX_TIME end


-- Helper function to run a test and catch the simulated exit error
local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(not ok and string.find(err, "Kong response exit called") or ok, "Test should either pass or simulate Kong exit")
end

-- --- Unit Test: new() method ---
do
    reset_mock_kong()
    local instance = GenerateJWTHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == GenerateJWTHandler, "Instance should have correct metatable")
end

-- --- Scenario 1: Successful JWT generation (HS256, literal secret, standard claims, header destination) ---
do
    reset_mock_kong()
    local conf = {
        jwt_generate_service_url = "http://mock-jwt-service.com/generate",
        algorithm = "HS256",
        secret_source_type = "literal", secret_literal = "my-secret-key",
        subject_source_type = "literal", subject_source_name = "test_user",
        issuer_source_type = "literal", issuer_source_name = "test_issuer",
        expires_in_seconds = 3600, -- 1 hour
        output_destination_type = "header", output_destination_name = "X-Generated-JWT",
        on_error_continue = false,
    }
    mock_kong.http.client.go = function(url, opts)
        local request_body_table = cjson.decode(opts.body)
        assert(request_body_table.claims.sub == "test_user", "Claims: sub should match")
        assert(request_body_table.claims.iss == "test_issuer", "Claims: iss should match")
        assert(request_body_table.claims.exp == (MOCK_NGX_TIME + 3600), "Claims: exp should be calculated correctly")
        assert(request_body_table.key == "my-secret-key", "Secret key should be sent")
        assert(request_body_table.algorithm == "HS256", "Algorithm should be HS256")
        return { status = 200, body = cjson.encode({ jwt = "generated.hs256.jwt" }) }, nil
    end

    local instance = GenerateJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on successful generation")
    assert(mock_kong.request.set_header_called, "kong.request.set_header should be called")
    assert(mock_kong.request.set_header_args[1] == "X-Generated-JWT", "Header name should match")
    assert(mock_kong.request.set_header_args[2] == "generated.hs256.jwt", "Generated JWT should be set in header")
end

-- --- Scenario 2: Successful JWT generation (RS256, shared private key, additional claims, query destination) ---
do
    reset_mock_kong()
    mock_kong.ctx.shared.my_private_key = "MOCK_RS256_PRIVATE_KEY"
    mock_kong.ctx.shared.custom_claim_value = "dynamic_value"

    local conf = {
        jwt_generate_service_url = "http://mock-jwt-service.com/generate",
        algorithm = "RS256",
        private_key_source_type = "shared_context", private_key_source_name = "my_private_key",
        subject_source_type = "literal", subject_source_name = "rs_user",
        additional_claims = {
            { claim_name = "custom_field", claim_value_source_type = "shared_context", claim_value_source_name = "custom_claim_value" }
        },
        output_destination_type = "query", output_destination_name = "jwt_token",
        on_error_continue = false,
    }
    mock_kong.http.client.go = function(url, opts)
        local request_body_table = cjson.decode(opts.body)
        assert(request_body_table.claims.sub == "rs_user", "Claims: sub should match")
        assert(request_body_table.claims.custom_field == "dynamic_value", "Claims: custom_field should match")
        assert(request_body_table.key == "MOCK_RS256_PRIVATE_KEY", "Private key should be sent")
        assert(request_body_table.algorithm == "RS256", "Algorithm should be RS256")
        return { status = 200, body = cjson.encode({ jwt = "generated.rs256.jwt" }) }, nil
    end

    local instance = GenerateJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on successful generation")
    assert(mock_kong.request.set_query_arg_called, "kong.request.set_query_arg should be called")
    assert(mock_kong.request.set_query_arg_args[1] == "jwt_token", "Query param name should match")
    assert(mock_kong.request.set_query_arg_args[2] == "generated.rs256.jwt", "Generated JWT should be set in query")
end

-- --- Scenario 3: Missing secret key for HS algorithm. ---
do
    reset_mock_kong()
    local conf = {
        jwt_generate_service_url = "http://mock-jwt-service.com/generate",
        algorithm = "HS256",
        secret_source_type = "shared_context", secret_source_name = "missing_secret",
        output_destination_type = "header", output_destination_name = "X-Generated-JWT",
        on_error_status = 401, on_error_body = "Unauthorized Key", on_error_continue = false,
    }
    -- mock_kong.ctx.shared.missing_secret will be nil by default
    local instance = GenerateJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit on missing secret key")
    assert(mock_kong.response.exit_args.status == 401, "Status should match config")
    assert(mock_kong.log.err_called, "Error should be logged for missing secret")
    assert(string.find(mock_kong.log.err_args[1], "Secret key not found for HS algorithm"), "Error message should indicate missing secret")
end

-- --- Scenario 4: Missing private key for RS algorithm (on_error_continue = true). ---
do
    reset_mock_kong()
    local conf = {
        jwt_generate_service_url = "http://mock-jwt-service.com/generate",
        algorithm = "RS256",
        private_key_source_type = "shared_context", private_key_source_name = "missing_private_key_rs",
        output_destination_type = "header", output_destination_name = "X-Generated-JWT",
        on_error_continue = true,
    }
    -- mock_kong.ctx.shared.missing_private_key_rs will be nil by default
    local instance = GenerateJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on missing private key when on_error_continue is true")
    assert(mock_kong.log.err_called, "Error should be logged for missing private key")
    assert(string.find(mock_kong.log.err_args[1], "Private key not found for RS/ES algorithm"), "Error message should indicate missing private key")
end

-- --- Scenario 5: External service call network failure (on_error_continue = false). ---
do
    reset_mock_kong()
    local conf = {
        jwt_generate_service_url = "http://mock-jwt-service.com/generate",
        algorithm = "HS256", secret_source_type = "literal", secret_literal = "KEY",
        output_destination_type = "header", output_destination_name = "X-Generated-JWT",
        on_error_status = 502, on_error_body = "Generator Service Down", on_error_continue = false,
    }
    mock_kong.http.client.go = function(...) return nil, "connection refused" end -- Simulate network error

    local instance = GenerateJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit on service network failure")
    assert(mock_kong.response.exit_args.status == 502, "Status should match config")
    assert(mock_kong.log.err_called, "Error should be logged for service call failure")
    assert(string.find(mock_kong.log.err_args[1], "Call to JWT generate service .* failed"), "Error message should match")
end

-- --- Scenario 6: External service returns non-200 status (on_error_continue = true). ---
do
    reset_mock_kong()
    local conf = {
        jwt_generate_service_url = "http://mock-jwt-service.com/generate",
        algorithm = "HS256", secret_source_type = "literal", secret_literal = "KEY",
        output_destination_type = "header", output_destination_name = "X-Generated-JWT",
        on_error_continue = true,
    }
    mock_kong.http.client.go = function(...) return { status = 403, body = "Invalid Algorithm" }, nil end -- Simulate non-200

    local instance = GenerateJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on non-200 from service when on_error_continue is true")
    assert(mock_kong.log.err_called, "Error should be logged for non-200 service response")
    assert(string.find(mock_kong.log.err_args[1], "JWT generate service .* returned error status: 403"), "Error message should match")
    assert(mock_kong.request.set_header_called == nil, "JWT should not be set on error")
end

-- --- Scenario 7: Different output_destination_type (body with JSON path). ---
do
    reset_mock_kong()
    local conf = {
        jwt_generate_service_url = "http://mock-jwt-service.com/generate",
        algorithm = "HS256", secret_source_type = "literal", secret_literal = "KEY",
        subject_source_type = "literal", subject_source_name = "body_jwt_user",
        output_destination_type = "body", output_destination_name = "authentication.jwt",
        on_error_continue = false,
    }
    local original_request_body = cjson.encode({ user = "original" })
    mock_kong.request.get_raw_body = function() return original_request_body end

    local instance = GenerateJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.request.set_body_called, "kong.request.set_body should be called")
    local updated_body = cjson.decode(mock_kong.request.set_body_args[1])
    assert(updated_body.authentication.jwt == "generated.mock.jwt.string", "JWT should be inserted into body JSON path")
    assert(updated_body.user == "original", "Other body content should be preserved")
    assert(mock_kong.request.set_header_args[1] == "Content-Type" and mock_kong.request.set_header_args[2] == "application/json", "Content-Type should be set to application/json")
end

-- --- Scenario 8: Replacing entire request body with JWT. ---
do
    reset_mock_kong()
    local conf = {
        jwt_generate_service_url = "http://mock-jwt-service.com/generate",
        algorithm = "HS256", secret_source_type = "literal", secret_literal = "KEY",
        subject_source_type = "literal", subject_source_name = "full_body_jwt_user",
        output_destination_type = "body", output_destination_name = ".", -- Replace entire body
        on_error_continue = false,
    }
    local original_request_body = "Any body content"
    mock_kong.request.get_raw_body = function() return original_request_body end

    local instance = GenerateJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.request.set_body_called, "kong.request.set_body should be called")
    assert(mock_kong.request.set_body_args[1] == "generated.mock.jwt.string", "Entire body should be replaced with JWT")
    assert(mock_kong.request.set_header_args[1] == "Content-Type" and mock_kong.request.set_header_args[2] == "text/plain", "Content-Type should be set to text/plain")
end


print("All generate-jwt extended tests passed!")