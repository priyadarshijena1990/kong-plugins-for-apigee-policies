-- Extended functional and unit tests for the decode-jwt plugin

local handler_module = require("kong.plugins.decode-jwt.handler")
local DecodeJWTHandler = handler_module -- The module itself is the handler class
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
        tools = {
            utils = {
                decode_base64 = function(str)
                    -- Simple base64 decode mock for testing
                    -- In real Kong, this is a C function
                    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
                    return ((str:gsub('[^'..b..'=]', ''):gsub('.', function(x)
                        if x == '=' then return '' end
                        local v = b:find(x) - 1
                        return ('000000'):sub(1, 6 - #v) .. v:rep(1)
                    end):gsub('%f[%w%w%w%w](%w%w%w%w)', function(x)
                        return string.char(tonumber(x:sub(1,2), 2) * 64 + tonumber(x:sub(3,4), 2) * 16 + tonumber(x:sub(5,6), 2))
                    end)))
                end,
            }
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
    local instance = DecodeJWTHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == DecodeJWTHandler, "Instance should have correct metatable")
end

-- Sample valid JWT:
-- Header: {"alg":"HS256","typ":"JWT"}
-- Payload: {"sub":"1234567890","name":"John Doe","iat":1516239022}
-- Full JWT: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.TJVA95OrM7E2cBab30RMHrHDcEfxjoYZgeFONFh7HgQ
local VALID_JWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.TJVA95OrM7E2cBab30RMHrHDcEfxjoYZgeFONFh7HgQ"
local VALID_JWT_HEADER = { alg = "HS256", typ = "JWT" }
local VALID_JWT_PAYLOAD = { sub = "1234567890", name = "John Doe", iat = 1516239022 }


-- --- Scenario 1: Successful JWT decoding and claim/header extraction (header source) ---
do
    reset_mock_kong()
    local conf = {
        jwt_source_type = "header",
        jwt_source_name = "X-Auth-JWT",
        claims_to_extract = {
            { claim_name = "sub", output_key = "jwt_subject" },
            { claim_name = "name", output_key = "jwt_name" },
        },
        store_all_claims_in_shared_context_key = "jwt_payload",
        store_header_to_shared_context_key = "jwt_header",
        on_error_continue = false,
    }
    
    mock_kong.request.get_header = function(name)
        if name == conf.jwt_source_name then return VALID_JWT end
    end
    
    local instance = DecodeJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on successful decoding")
    assert(mock_kong.ctx.shared["jwt_subject"] == "1234567890", "Should extract 'sub' claim")
    assert(mock_kong.ctx.shared["jwt_name"] == "John Doe", "Should extract 'name' claim")
    assert(type(mock_kong.ctx.shared["jwt_payload"]) == "table", "Should store payload as table")
    assert(mock_kong.ctx.shared["jwt_payload"].sub == VALID_JWT_PAYLOAD.sub, "Stored payload 'sub' should match")
    assert(type(mock_kong.ctx.shared["jwt_header"]) == "table", "Should store header as table")
    assert(mock_kong.ctx.shared["jwt_header"].alg == VALID_JWT_HEADER.alg, "Stored header 'alg' should match")
end

-- --- Scenario 2: Invalid JWT format (too few parts) ---
do
    reset_mock_kong()
    local conf = {
        jwt_source_type = "header", jwt_source_name = "X-Bad-JWT",
        on_error_status = 400, on_error_body = "Bad JWT", on_error_continue = false,
    }
    mock_kong.request.get_header = function(...) return "header.payload" end -- Two parts
    
    local instance = DecodeJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit on invalid JWT format")
    assert(mock_kong.response.exit_args.status == 400, "Should return configured error status")
    assert(mock_kong.log.err_called, "Error should be logged for invalid format")
    assert(string.find(mock_kong.log.err_args[1], "Invalid JWT format"), "Error message should indicate invalid format")
end

-- --- Scenario 3: Failed base64url decoding of header ---
do
    reset_mock_kong()
    local conf = {
        jwt_source_type = "header", jwt_source_name = "X-Bad-B64-Header",
        on_error_status = 400, on_error_body = "Bad Header Encoding", on_error_continue = false,
    }
    mock_kong.request.get_header = function(...) return "!.payload.signature" end -- Invalid base64 in header part
    
    local instance = DecodeJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit on failed base64url decode (header)")
    assert(mock_kong.log.err_called, "Error should be logged for b64 decode failure")
    assert(string.find(mock_kong.log.err_args[1], "Failed to base64url decode JWT header"), "Error message should indicate b64 decode error")
end

-- --- Scenario 4: Failed JSON decoding of payload ---
do
    reset_mock_kong()
    local conf = {
        jwt_source_type = "header", jwt_source_name = "X-Bad-JSON-Payload",
        on_error_status = 400, on_error_body = "Bad Payload JSON", on_error_continue = false,
    }
    -- Valid base64 header, valid base64 but invalid JSON payload
    local bad_json_payload = mock_kong.tools.utils.decode_base64("e3JhbmRvbV90ZXh0") -- Invalid JSON: {"random_text
    local jwt_with_bad_json = "eyJhbGciOiJIUzI1NiJ9." .. bad_json_payload .. ".signature" -- This is not correct mock setup
    
    -- Manually set the base64url_decode to return bad JSON for part 2
    local original_base64url_decode = mock_kong.tools.utils.decode_base64
    mock_kong.tools.utils.decode_base64 = function(str)
        if str == "e3JhbmRvbV90ZXh0" then return "{random_text" end -- Mock return invalid JSON string
        return original_base64url_decode(str)
    end
    mock_kong.request.get_header = function(...) return "eyJhbGciOiJIUzI1NiJ9.e3JhbmRvbV90ZXh0.signature" end
    
    local instance = DecodeJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)
    
    assert(mock_kong.response.exit_called, "Should exit on failed JSON decode (payload)")
    assert(mock_kong.log.err_called, "Error should be logged for JSON decode failure")
    assert(string.find(mock_kong.log.err_args[1], "Failed to JSON decode JWT payload"), "Error message should indicate JSON decode error")
    
    -- Restore original for other tests
    mock_kong.tools.utils.decode_base64 = original_base64url_decode
end

-- --- Scenario 5: JWT not found from query (on_error_continue = true) ---
do
    reset_mock_kong()
    local conf = {
        jwt_source_type = "query", jwt_source_name = "jwt_param",
        on_error_continue = true,
    }
    -- mock_kong.request.get_query_arg will return nil by default
    local instance = DecodeJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit when JWT not found and on_error_continue is true")
    assert(mock_kong.log.err_called, "Error should be logged for missing JWT")
    assert(string.find(mock_kong.log.err_args[1], "No JWT string found from source"), "Error message should indicate missing JWT")
end

-- --- Scenario 6: JWT from Authorization: Bearer header ---
do
    reset_mock_kong()
    local conf = {
        jwt_source_type = "header", jwt_source_name = "Authorization",
        claims_to_extract = { { claim_name = "sub", output_key = "auth_jwt_subject" } },
        on_error_continue = false,
    }
    mock_kong.request.get_header = function(name)
        if name == "Authorization" then return "Bearer " .. VALID_JWT end
    end
    
    local instance = DecodeJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on successful auth header JWT extraction")
    assert(mock_kong.ctx.shared["auth_jwt_subject"] == VALID_JWT_PAYLOAD.sub, "Should extract claim from auth header JWT")
end

-- --- Scenario 7: JWT from request body with JSON path ---
do
    reset_mock_kong()
    local conf = {
        jwt_source_type = "body",
        jwt_source_name = "credentials.jwt_token", -- JSON path
        claims_to_extract = { { claim_name = "name", output_key = "body_jwt_name" } },
        on_error_continue = false,
    }
    mock_kong.request.get_raw_body = function()
        return cjson.encode({
            user_info = {
                credentials = {
                    jwt_token = VALID_JWT,
                    api_key = "123"
                }
            }
        })
    end
    
    local instance = DecodeJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit on successful body JWT extraction")
    assert(mock_kong.ctx.shared["body_jwt_name"] == VALID_JWT_PAYLOAD.name, "Should extract claim from body JWT")
end

-- --- Scenario 8: Extracting a claim that does not exist ---
do
    reset_mock_kong()
    local conf = {
        jwt_source_type = "header", jwt_source_name = "X-Auth-JWT",
        claims_to_extract = {
            { claim_name = "sub", output_key = "jwt_subject_present" },
            { claim_name = "non_existent_claim", output_key = "jwt_claim_missing" },
        },
        on_error_continue = false,
    }
    mock_kong.request.get_header = function(...) return VALID_JWT end
    
    local instance = DecodeJWTHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit for missing claim")
    assert(mock_kong.ctx.shared["jwt_subject_present"] == VALID_JWT_PAYLOAD.sub, "Existing claim should be extracted")
    assert(mock_kong.ctx.shared["jwt_claim_missing"] == nil, "Missing claim should not be added to shared context")
end


print("All decode-jwt extended tests passed!")