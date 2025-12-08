-- Unit tests for the verify-jws plugin

local handler_module = require("kong.plugins.verify-jws.handler")
local VerifyJwsHandler = handler_module

-- Mock dependencies
local mock_kong = {}
local mock_jwt = {}

-- HS256 token for '{"sub":"1234567890","name":"John Doe","iat":1516239022}' with secret 'test-secret'
local hs256_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

local function reset_mocks()
    mock_kong = {
        request = {
            get_header = function(name) return mock_kong.request.headers[name] end,
            get_query = function() return mock_kong.request.query_args end,
            get_raw_body = function() return mock_kong.request.raw_body, nil end,
            headers = {},
            query_args = {},
            raw_body = "",
        },
        response = {
            exit_called = false,
            exit_args = {},
            exit = function(status, body)
                mock_kong.response.exit_called = true
                mock_kong.response.exit_args = { status = status, body = body }
                error("kong.response.exit called")
            end,
        },
        ctx = {
            shared = {},
        },
        log = {
            err = function(...) end,
            debug = function(...) end,
        },
        cache = {
            get = function() return nil end,
            set = function() end,
        },
    }

    mock_jwt = {
        verify = function(token, secret)
            if token == hs256_token and secret == "test-secret" then
                return {
                    header = { alg = "HS256", typ = "JWT" },
                    payload = { sub = "1234567890", name = "John Doe", iat = 1516239022 },
                }
            end
            return nil, "invalid signature"
        end,
    }

    -- Inject mocks
    _G.kong = mock_kong
    package.loaded["resty.jwt"] = mock_jwt
    package.loaded["resty.http"] = { new = function() return { request_uri = function() return nil, "mock http client" end } end }
end

local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(ok or string.find(err, "kong.response.exit called"), "Test should either pass or simulate Kong exit")
end

-- --- Test Suite ---

describe("verify-jws handler", function()

    before_each(reset_mocks)

    it("Scenario 1: should verify a valid HS256 token from header and store claims", function()
        local conf = {
            jws_source_type = "header",
            jws_source_name = "Authorization",
            algorithm = "HS256",
            key_source = "literal_secret",
            secret = "test-secret",
            output_claims_to = "jwt_claims",
        }
        mock_kong.request.headers["Authorization"] = "Bearer " .. hs256_token

        local instance = VerifyJwsHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.falsy(mock_kong.response.exit_called, "Should not exit on success")
        assert.is_not_nil(mock_kong.ctx.shared.jwt_claims, "Claims should be stored in shared context")
        assert.are.equal("1234567890", mock_kong.ctx.shared.jwt_claims.sub)
    end)

    it("Scenario 2: should fail with an invalid signature", function()
        local conf = { jws_source_type = "header", jws_source_name = "X-JWS", algorithm = "HS256", key_source = "literal_secret", secret = "wrong-secret" }
        mock_kong.request.headers["X-JWS"] = hs256_token

        local instance = VerifyJwsHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.truthy(mock_kong.response.exit_called, "Should exit on verification failure")
        assert.are.equal(401, mock_kong.response.exit_args.status)
        assert.string.matches(mock_kong.response.exit_args.body.message, "Failed to verify JWS")
    end)

    it("Scenario 3: should fail when token is not found", function()
        local conf = { jws_source_type = "query", jws_source_name = "jwt" }

        local instance = VerifyJwsHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.truthy(mock_kong.response.exit_called, "Should exit when token is missing")
        assert.are.equal(401, mock_kong.response.exit_args.status)
        assert.string.matches(mock_kong.response.exit_args.body.message, "JWS token not found")
    end)
end)