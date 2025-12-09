-- Extended functional and unit tests for the decode-jws plugin

local handler_module = require("kong.plugins.decode-jws.handler")
local DecodeJWSHandler = handler_module -- The module itself is the handler class
local cjson = require "cjson"

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        request = {
            get_header = function(...) return nil end,
            get_query_arg = function(...) return nil end,
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
                    return { status = 200, body = cjson.encode({ header = { alg = "RS256" }, payload = { sub = "test_user", iss = "kong" } }) }, nil
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
    local instance = DecodeJWSHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == DecodeJWSHandler, "Instance should have correct metatable")
end

-- --- Scenario 1: Successful JWS decoding and claim extraction (header, literal key) ---
do
    reset_mock_kong()
    local conf = {
        jws_decode_service_url = "http://mock-jws-service.com/decode",
        jws_source_type = "header",
        jws_source_name = "X-JWS-Token",
        public_key_source_type = "literal",
        public_key_literal = "MOCK_PUBLIC_KEY_LITERAL",
        claims_to_extract = {
            { claim_name = "sub", output_key = "jws_subject" },
            { claim_name = "iss", output_key = "jws_issuer" },
            { claim_name = "aud", output_key = "jws_audience" }, -- Claim not in mock, should be skipped
        },
        on_error_continue = false,
    }
    
    mock_kong.request.get_header = function(name)
        if name == conf.jws_source_name then return "mock.jws.string" end
    end
    
    local instance = DecodeJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on success")
    assert(mock_kong.ctx.shared["jws_subject"] == "test_user", "Should extract 'sub' claim")
    assert(mock_kong.ctx.shared["jws_issuer"] == "kong", "Should extract 'iss' claim")
    assert(mock_kong.ctx.shared["jws_audience"] == nil, "Should not extract missing 'aud' claim")
end

-- --- Scenario 2: JWS not found from header (on_error_continue = false) ---
do
    reset_mock_kong()
    local conf = {
        jws_decode_service_url = "http://mock-jws-service.com/decode",
        jws_source_type = "header",
        jws_source_name = "X-JWS-Token",
        public_key_source_type = "literal",
        public_key_literal = "MOCK_PUBLIC_KEY_LITERAL",
        claims_to_extract = {},
        on_error_status = 400,
        on_error_body = "Missing JWS",
        on_error_continue = false,
    }
    -- mock_kong.request.get_header will return nil by default
    local instance = DecodeJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit when JWS not found and on_error_continue is false")
    assert(mock_kong.response.exit_args.status == 400, "Should return configured error status")
    assert(mock_kong.response.exit_args.body == "Missing JWS", "Should return configured error body")
    assert(mock_kong.log.err_called, "Error should be logged for missing JWS")
    assert(string.find(mock_kong.log.err_args[1], "No JWS string found from source"), "Error message should indicate missing JWS")
end

-- --- Scenario 3: JWS not found from query (on_error_continue = true) ---
do
    reset_mock_kong()
    local conf = {
        jws_decode_service_url = "http://mock-jws-service.com/decode",
        jws_source_type = "query",
        jws_source_name = "jws_token",
        public_key_source_type = "literal",
        public_key_literal = "MOCK_PUBLIC_KEY_LITERAL",
        claims_to_extract = {},
        on_error_continue = true,
    }
    -- mock_kong.request.get_query_arg will return nil by default
    local instance = DecodeJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit when JWS not found and on_error_continue is true")
    assert(mock_kong.log.err_called, "Error should be logged for missing JWS")
end

-- --- Scenario 4: Public key not found from shared_context (on_error_continue = false) ---
do
    reset_mock_kong()
    local conf = {
        jws_decode_service_url = "http://mock-jws-service.com/decode",
        jws_source_type = "header",
        jws_source_name = "X-JWS-Token",
        public_key_source_type = "shared_context",
        public_key_source_name = "my_public_key",
        claims_to_extract = {},
        on_error_status = 500,
        on_error_body = "Missing Public Key",
        on_error_continue = false,
    }
    mock_kong.request.get_header = function(name) if name == conf.jws_source_name then return "mock.jws.string" end end
    -- mock_kong.ctx.shared["my_public_key"] will be nil by default
    local instance = DecodeJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit when public key not found and on_error_continue is false")
    assert(mock_kong.response.exit_args.status == 500, "Should return configured error status")
    assert(mock_kong.response.exit_args.body == "Missing Public Key", "Should return configured error body")
    assert(mock_kong.log.err_called, "Error should be logged for missing public key")
    assert(string.find(mock_kong.log.err_args[1], "No public key found from source"), "Error message should indicate missing public key")
end

-- --- Scenario 5: External JWS service network failure (on_error_continue = false) ---
do
    reset_mock_kong()
    local conf = {
        jws_decode_service_url = "http://mock-jws-service.com/decode",
        jws_source_type = "header", jws_source_name = "X-JWS-Token",
        public_key_source_type = "literal", public_key_literal = "KEY",
        claims_to_extract = {}, on_error_status = 502, on_error_body = "Gateway Error", on_error_continue = false,
    }
    mock_kong.request.get_header = function(...) return "mock.jws.string" end
    mock_kong.http.client.go = function(...) return nil, "connection refused" end -- Simulate network error

    local instance = DecodeJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit on service network failure")
    assert(mock_kong.response.exit_args.status == 502, "Should return configured error status")
    assert(mock_kong.response.exit_args.body == "Gateway Error", "Should return configured error body")
    assert(mock_kong.log.err_called, "Error should be logged for service call failure")
    assert(string.find(mock_kong.log.err_args[1], "Call to JWS decode service .* failed"), "Error message should match")
end

-- --- Scenario 6: External JWS service returns non-200 status (on_error_continue = true) ---
do
    reset_mock_kong()
    local conf = {
        jws_decode_service_url = "http://mock-jws-service.com/decode",
        jws_source_type = "header", jws_source_name = "X-JWS-Token",
        public_key_source_type = "literal", public_key_literal = "KEY",
        claims_to_extract = {}, on_error_continue = true,
    }
    mock_kong.request.get_header = function(...) return "mock.jws.string" end
    mock_kong.http.client.go = function(...) return { status = 401, body = "Invalid JWS" }, nil end -- Simulate non-200 response

    local instance = DecodeJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on non-200 from service when on_error_continue is true")
    assert(mock_kong.log.err_called, "Error should be logged for non-200 service response")
    assert(string.find(mock_kong.log.err_args[1], "JWS decode service .* returned error status: 401"), "Error message should match")
end

-- --- Scenario 7: External JWS service returns invalid JSON body ---
do
    reset_mock_kong()
    local conf = {
        jws_decode_service_url = "http://mock-jws-service.com/decode",
        jws_source_type = "header", jws_source_name = "X-JWS-Token",
        public_key_source_type = "literal", public_key_literal = "KEY",
        claims_to_extract = {}, on_error_continue = false,
    }
    mock_kong.request.get_header = function(...) return "mock.jws.string" end
    mock_kong.http.client.go = function(...) return { status = 200, body = "NOT JSON" }, nil end -- Simulate invalid JSON

    local instance = DecodeJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit on invalid JSON from service")
    assert(mock_kong.log.err_called, "Error should be logged for JSON decode failure")
    assert(string.find(mock_kong.log.err_args[1], "Failed to decode JSON response from JWS decode service"), "Error message should match")
end

-- --- Scenario 8: External JWS service response missing 'payload' ---
do
    reset_mock_kong()
    local conf = {
        jws_decode_service_url = "http://mock-jws-service.com/decode",
        jws_source_type = "header", jws_source_name = "X-JWS-Token",
        public_key_source_type = "literal", public_key_literal = "KEY",
        claims_to_extract = {}, on_error_continue = false,
    }
    mock_kong.request.get_header = function(...) return "mock.jws.string" end
    mock_kong.http.client.go = function(...) return { status = 200, body = cjson.encode({ header = {} }) }, nil end -- Missing payload

    local instance = DecodeJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit on missing 'payload' in service response")
    assert(mock_kong.log.err_called, "Error should be logged for missing payload")
    assert(string.find(mock_kong.log.err_args[1], "JWS decode service response missing 'payload' claims"), "Error message should match")
end

-- --- Scenario 9: JWS from Authorization: Bearer header ---
do
    reset_mock_kong()
    local conf = {
        jws_decode_service_url = "http://mock-jws-service.com/decode",
        jws_source_type = "header", jws_source_name = "Authorization", -- Note 'Authorization'
        public_key_source_type = "literal", public_key_literal = "KEY",
        claims_to_extract = { { claim_name = "sub", output_key = "auth_subject" } },
        on_error_continue = false,
    }
    mock_kong.request.get_header = function(name)
        if name == "Authorization" then return "Bearer mock.auth.jws.string" end
    end
    mock_kong.http.client.go = function(...)
        local _, _, body_json = string.find(select(2, ...), 'body=(.*)$')
        local body_table = cjson.decode(body_json)
        assert(body_table.jws == "mock.auth.jws.string", "External service should receive extracted JWS")
        return { status = 200, body = cjson.encode({ header = {}, payload = { sub = "auth_user" } }) }, nil
    end

    local instance = DecodeJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on successful auth header JWS extraction")
    assert(mock_kong.ctx.shared["auth_subject"] == "auth_user", "Should extract claim from auth header JWS")
end

-- --- Scenario 10: JWS from request body with JSON path ---
do
    reset_mock_kong()
    local conf = {
        jws_decode_service_url = "http://mock-jws-service.com/decode",
        jws_source_type = "body",
        jws_source_name = "token.jws", -- JSON path
        public_key_source_type = "literal", public_key_literal = "KEY",
        claims_to_extract = { { claim_name = "sub", output_key = "body_jws_subject" } },
        on_error_continue = false,
    }
    mock_kong.request.get_raw_body = function()
        return cjson.encode({
            request_id = "123",
            token = {
                jws = "body.jws.string",
                type = "JWT"
            }
        })
    end
    mock_kong.http.client.go = function(...)
        local _, _, body_json = string.find(select(2, ...), 'body=(.*)$')
        local body_table = cjson.decode(body_json)
        assert(body_table.jws == "body.jws.string", "External service should receive JWS from body JSON path")
        return { status = 200, body = cjson.encode({ header = {}, payload = { sub = "body_user" } }) }, nil
    end

    local instance = DecodeJWSHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on successful body JWS extraction")
    assert(mock_kong.ctx.shared["body_jws_subject"] == "body_user", "Should extract claim from body JWS")
end


print("All decode-jws extended tests passed!")