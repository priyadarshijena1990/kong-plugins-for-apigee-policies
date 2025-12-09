local helpers = require("spec.helpers")
local busted = require("busted.runner")()
local assert = busted.assert
local inspect = require("inspect")
local cjson = require("cjson")

describe("Plugin: get-oauth-v2-info", function()

  local client
  local service
  local consumer
  local oauth2_credential

  -- Custom OAuth2 plugin to simulate specific scopes and attributes
  local oauth2_plugin_mock = {
    name = "oauth2",
    service = service,
    config = {
      global_credentials = true, -- For simplicity, allow any valid token
      enable_client_credentials = true,
      token_introspection_endpoint = "http://mock-oauth2-server/introspect",
      access_token_strategies = {"header", "query"},
    }
  }

  before_each(function()
    -- Create a service
    service = helpers.dao.services:insert {
      name = "my-service",
      host = helpers.mock_upstream_host,
      port = helpers.mock_upstream_port,
    }

    -- Create a consumer with custom data
    consumer = helpers.dao.consumers:insert {
      username = "oauth_user",
      custom_id = "user_456",
    }

    -- Create an OAuth2 credential for the consumer with custom scopes/attributes
    -- In a real scenario, these would come from the OAuth2 plugin's introspection
    oauth2_credential = helpers.dao.oauth2_credentials:insert {
      consumer = consumer,
      client_id = "test-client-id",
      client_secret = "test-client-secret",
      name = "TestApplication", -- App name
      -- Simulate attributes usually associated with the token or consumer in shared context
      tags = { "scope:read", "scope:write", "tier:gold" }
    }

    -- Mock the OAuth2 server to return introspected data
    helpers.mock_http_server(function(req, res)
      if req.path == "/introspect" then
        if req.headers["authorization"] == "Bearer valid_access_token" then
          res:send(200, cjson.encode({
            active = true,
            scope = "read write",
            client_id = oauth2_credential.client_id,
            username = consumer.username,
            custom_attribute_from_oauth_server = "extra_data",
          }))
        else
          res:send(401, "Invalid Token")
        end
      else
        res:send(404, "Not Found")
      end
    end)

    -- Create a route for the service
    helpers.dao.routes:insert {
      hosts = { "get-oauth-v2-info.com" },
      services = { service },
    }

    -- Start the Kong client
    client = helpers.http_client()
  end)

  after_each(function()
    if client then
      client:close()
    end
    helpers.stop_kong()
  end)

  it("should extract standard OAuth2 info and custom attributes to shared context", function()
    local expected_client_id = oauth2_credential.client_id
    local expected_app_name = oauth2_credential.name
    local expected_end_user = consumer.username
    local expected_scopes = "read write"
    local expected_custom_attr = "extra_data"

    assert(helpers.start_kong({
      plugins = {
        oauth2_plugin_mock, -- This sets up authenticated_credential and possibly oauth2_token
        { -- Enable get-oauth-v2-info plugin on the service
          name = "get-oauth-v2-info",
          service = service,
          config = {
            extract_client_id_to_shared_context_key = "oauth_client_id",
            extract_app_name_to_shared_context_key = "oauth_app_name",
            extract_end_user_to_shared_context_key = "oauth_end_user",
            extract_scopes_to_shared_context_key = "oauth_scopes",
            extract_custom_attributes = {
              { source_field = "custom_attribute_from_oauth_server", output_key = "custom_oauth_data" },
            }
          }
        },
        { -- Add a helper plugin to capture kong.ctx.shared
          name = "log-shared-context",
          service = service,
          config = {
            log_key = "get_oauth_v2_info_test_data",
            target_key_prefix = ""
          }
        }
      }
    }))

    local res = client:get("/", { headers = { host = "get-oauth-v2-info.com", authorization = "Bearer valid_access_token" } })
    assert.response(res).has.status(200)

    local logs = helpers.get_plugin_log("log-shared-context", "get_oauth_v2_info_test_data")
    assert.is_table(logs)

    assert.are.same(expected_client_id, logs.oauth_client_id)
    assert.are.same(expected_app_name, logs.oauth_app_name)
    assert.are.same(expected_end_user, logs.oauth_end_user)
    assert.are.same(expected_scopes, logs.oauth_scopes)
    assert.are.same(expected_custom_attr, logs.custom_oauth_data)
  end)

  it("should handle cases where not all info is available (e.g., no scopes or custom attrs)", function()
    assert(helpers.stop_kong()) -- Stop Kong to restart with modified plugins
    assert(helpers.start_kong({
      plugins = {
        oauth2_plugin_mock,
        {
          name = "get-oauth-v2-info",
          service = service,
          config = {
            extract_client_id_to_shared_context_key = "oauth_client_id",
            -- Only extract client_id, omit others to test nil handling
            extract_custom_attributes = {}, -- No custom attributes
          }
        },
        {
          name = "log-shared-context",
          service = service,
          config = {
            log_key = "get_oauth_v2_info_test_data_partial",
            target_key_prefix = ""
          }
        }
      }
    }))

    local res = client:get("/", { headers = { host = "get-oauth-v2-info.com", authorization = "Bearer valid_access_token" } })
    assert.response(res).has.status(200)

    local logs = helpers.get_plugin_log("log-shared-context", "get_oauth_v2_info_test_data_partial")
    assert.is_table(logs)

    assert.are.same(oauth2_credential.client_id, logs.oauth_client_id)
    assert.is_nil(logs.oauth_app_name)
    assert.is_nil(logs.oauth_end_user)
    assert.is_nil(logs.oauth_scopes)
  end)

  it("should handle no authenticated consumer/credential gracefully", function()
    assert(helpers.stop_kong()) -- Stop Kong to restart without OAuth2 plugin
    assert(helpers.start_kong({
      plugins = {
        {
          name = "get-oauth-v2-info",
          service = service,
          config = {
            extract_client_id_to_shared_context_key = "oauth_client_id",
          }
        },
        {
          name = "log-shared-context",
          service = service,
          config = {
            log_key = "get_oauth_v2_info_test_no_auth",
            target_key_prefix = ""
          }
        }
      }
    }))

    local res = client:get("/", { headers = { host = "get-oauth-v2-info.com" } }) -- No Authorization header
    assert.response(res).has.status(200)

    local logs = helpers.get_plugin_log("log-shared-context", "get_oauth_v2_info_test_no_auth")
    assert.is_table(logs)
    assert.is_nil(logs.oauth_client_id) -- Should not be set
  end)

end)
