-- Unit tests for the decode-jwt plugin

local handler_module = require("kong.plugins.decode-jwt.handler")
local DecodeJwtHandler = handler_module

-- Mock dependencies
local mock_kong = {}
local mock_jwt_lib = {}

-- A sample JWT (can be expired/invalid signature, doesn't matter for decoding)
local sample_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLTEyMyIsIm5hbWUiOiJUZXN0IFVzZXIiLCJpYXQiOjE1MTYyMzkwMjJ9.signature-does-not-matter"

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
    }

    mock_jwt_lib = {
        load_jwt = function(token)
            if token == sample_token then
                return {
                    header = { alg = "HS256", typ = "JWT" },
                    payload = { sub = "user-123", name = "Test User", iat = 1516239022 },
                }
            end
            return nil, "malformed token"
        end,
    }

    -- Inject mocks
    _G.kong = mock_kong
    package.loaded["resty.jwt"] = mock_jwt_lib
end

local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(ok or string.find(err, "kong.response.exit called"), "Test should either pass or simulate Kong exit")
end

-- --- Test Suite ---

describe("decode-jwt handler", function()

    before_each(reset_mocks)

    it("Scenario 1: should decode a valid JWT from header and store it", function()
        local conf = {
            jwt_source_type = "header",
            jwt_source_name = "Authorization",
            output_variable_name = "decoded_token",
        }
        mock_kong.request.headers["Authorization"] = "Bearer " .. sample_token

        local instance = DecodeJwtHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.falsy(mock_kong.response.exit_called, "Should not exit on success")
        assert.is_not_nil(mock_kong.ctx.shared.decoded_token, "Decoded token should be in shared context")
        assert.are.equal("user-123", mock_kong.ctx.shared.decoded_token.payload.sub)
    end)

    it("Scenario 2: should fail with a malformed token", function()
        local conf = { jwt_source_type = "query", jwt_source_name = "token", output_variable_name = "decoded_token", on_error_status = 400, on_error_body = "Bad JWT" }
        mock_kong.request.query_args["token"] = "this.is.not.a.jwt"

        local instance = DecodeJwtHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.truthy(mock_kong.response.exit_called, "Should exit on decoding failure")
        assert.are.equal(400, mock_kong.response.exit_args.status)
        assert.are.equal("Bad JWT", mock_kong.response.exit_args.body.message)
    end)

    it("Scenario 3: should fail when token is not found in the source", function()
        local conf = { jwt_source_type = "header", jwt_source_name = "X-Api-Token", output_variable_name = "decoded_token" }
        local instance = DecodeJwtHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)
        assert.truthy(mock_kong.response.exit_called, "Should exit when token is missing")
        assert.are.equal(400, mock_kong.response.exit_args.status)
    end)
end)