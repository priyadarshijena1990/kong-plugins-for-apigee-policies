-- Unit tests for the delete-oauth-v2-info plugin

local handler_module = require("kong.plugins.delete-oauth-v2-info.handler")
local DeleteOauthV2InfoHandler = handler_module

-- Mock dependencies
local mock_kong = {}
local mock_db = {}

local function reset_mocks()
    mock_db = {
        oauth2_tokens = {
            delete_called_with = nil,
            should_error = false,
            delete = function(self, query)
                self.delete_called_with = query
                if self.should_error then
                    return nil, "database connection error"
                end
                return true, nil
            end,
        },
    }

    mock_kong = {
        request = {
            get_header = function(name) return mock_kong.request.headers[name] end,
            get_query = function() return mock_kong.request.query_args end,
            headers = {},
            query_args = {},
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
        db = mock_db,
    }
    _G.kong = mock_kong
end

local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(ok or string.find(err, "kong.response.exit called"), "Test should either pass or simulate Kong exit")
end

-- --- Test Suite ---

describe("delete-oauth-v2-info handler", function()

    before_each(reset_mocks)

    it("Scenario 1: should delete a token found in a header", function()
        local conf = {
            token_source_type = "header",
            token_source_name = "X-Access-Token",
        }
        mock_kong.request.headers["X-Access-Token"] = "token-to-delete-123"

        local instance = DeleteOauthV2InfoHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.falsy(mock_kong.response.exit_called, "Should not exit on success")
        assert.is_not_nil(mock_db.oauth2_tokens.delete_called_with, "DB delete should have been called")
        assert.are.equal("token-to-delete-123", mock_db.oauth2_tokens.delete_called_with.access_token)
    end)

    it("Scenario 2: should fail if token is not found", function()
        local conf = { token_source_type = "query", token_source_name = "logout_token" }
        -- No token provided in mock_kong.request.query_args

        local instance = DeleteOauthV2InfoHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.truthy(mock_kong.response.exit_called, "Should exit when token is missing")
        assert.are.equal(400, mock_kong.response.exit_args.status)
    end)

    it("Scenario 3: should handle a database error on delete", function()
        local conf = { token_source_type = "header", token_source_name = "X-Access-Token" }
        mock_kong.request.headers["X-Access-Token"] = "some-token"
        mock_db.oauth2_tokens.should_error = true

        local instance = DeleteOauthV2InfoHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.truthy(mock_kong.response.exit_called, "Should exit on DB error")
        assert.are.equal(500, mock_kong.response.exit_args.status)
    end)
end)