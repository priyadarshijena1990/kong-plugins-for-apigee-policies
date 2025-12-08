local helpers = require("spec.helpers")
local busted = require("busted.runner")()
local assert = busted.assert
local inspect = require("inspect")
local cjson = require("cjson")

describe("Plugin: access-entity", function()

  local client
  local service
  local consumer
  local key_auth_credential

  before_each(function()
    -- Create a service
    service = helpers.dao.services:insert {
      name = "my-service",
      host = helpers.mock_upstream_host,
      port = helpers.mock_upstream_port,
    }

    -- Create a consumer with custom metadata
    consumer = helpers.dao.consumers:insert {
      username = "test_user",
      custom_id = "user_123",
      tags = { "tier:premium", "department:engineering" } -- Example custom data
    }

    -- Create a credential for the consumer (e.g., key-auth)
    key_auth_credential = helpers.dao.key_auth_credentials:insert {
      consumer = consumer,
      key = "my-api-key"
    }

    -- Create a route for the service
    helpers.dao.routes:insert {
      hosts = { "access-entity.com" },
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

  describe("when extracting from consumer entity", function()
    local expected_output_key_username = "authenticated_username"
    local expected_output_key_custom_id = "user_custom_id"
    local expected_output_key_tier = "user_tier"
    local expected_output_key_dept = "user_department"
    local expected_output_key_nonexistent = "non_existent_field"
    local expected_default_value = "default_val"

    before_each(function()
      assert(helpers.start_kong({
        -- Enable key-auth to authenticate the consumer
        plugins = {
          {
            name = "key-auth",
            service = service,
          },
          { -- Enable access-entity plugin on the service
            name = "access-entity",
            service = service,
            config = {
              entity_type = "consumer",
              extract_attributes = {
                { source_field = "username", output_key = expected_output_key_username },
                { source_field = "custom_id", output_key = expected_output_key_custom_id },
                { source_field = "tags", output_key = "consumer_tags" }, -- tags is an array
                { source_field = "non_existent", output_key = expected_output_key_nonexistent, default_value = expected_default_value },
              }
            }
          },
          { -- Add a helper plugin to capture kong.ctx.shared
            name = "log-shared-context",
            service = service,
            config = {
              log_key = "access_entity_test_data",
              target_key_prefix = "" -- Log all shared context
            }
          }
        }
      }))
    end)

    it("should extract specified attributes from the authenticated consumer to shared context", function()
      local res = client:get("/", { headers = { host = "access-entity.com", apikey = key_auth_credential.key } })
      assert.response(res).has.status(200)

      local logs = helpers.get_plugin_log("log-shared-context", "access_entity_test_data")
      assert.is_table(logs)

      assert.are.same(consumer.username, logs[expected_output_key_username])
      assert.are.same(consumer.custom_id, logs[expected_output_key_custom_id])
      -- Pongo's helpers.get_plugin_log will JSON decode, so tags will be a Lua table/array
      assert.is_table(logs.consumer_tags) 
      assert.are.same(consumer.tags[1], logs.consumer_tags[1])
      assert.are.same(consumer.tags[2], logs.consumer_tags[2])
      assert.are.same(expected_default_value, logs[expected_output_key_nonexistent])
    end)

    it("should not extract attributes if no consumer is authenticated", function()
      assert(helpers.stop_kong()) -- Stop Kong to restart with plugin but without key-auth
      assert(helpers.start_kong({
        plugins = {
          { -- Enable access-entity plugin on the service
            name = "access-entity",
            service = service,
            config = {
              entity_type = "consumer",
              extract_attributes = {
                { source_field = "username", output_key = expected_output_key_username },
              }
            }
          },
          { -- Add a helper plugin to capture kong.ctx.shared
            name = "log-shared-context",
            service = service,
            config = {
              log_key = "access_entity_test_data",
              target_key_prefix = ""
            }
          }
        }
      }))

      local res = client:get("/", { headers = { host = "access-entity.com" } }) -- No apikey
      assert.response(res).has.status(200) -- Should still hit upstream

      local logs = helpers.get_plugin_log("log-shared-context", "access_entity_test_data")
      assert.is_table(logs)
      assert.is_nil(logs[expected_output_key_username]) -- Should not be set
    end)
  end)

  describe("when extracting from credential entity", function()
    local expected_output_key_key = "credential_key"
    local expected_output_key_consumer_id = "credential_consumer_id"
    local expected_output_key_nonexistent = "non_existent_credential_field"
    local expected_default_value = "default_cred_val"


    before_each(function()
      assert(helpers.start_kong({
        plugins = {
          {
            name = "key-auth",
            service = service,
          },
          {
            name = "access-entity",
            service = service,
            config = {
              entity_type = "credential",
              extract_attributes = {
                { source_field = "key", output_key = expected_output_key_key },
                { source_field = "consumer_id", output_key = expected_output_key_consumer_id }, -- Key-auth credential has consumer_id
                { source_field = "non_existent", output_key = expected_output_key_nonexistent, default_value = expected_default_value },
              }
            }
          },
          {
            name = "log-shared-context",
            service = service,
            config = {
              log_key = "access_entity_credential_test_data",
              target_key_prefix = ""
            }
          }
        }
      }))
    end)

    it("should extract specified attributes from the authenticated credential to shared context", function()
      local res = client:get("/", { headers = { host = "access-entity.com", apikey = key_auth_credential.key } })
      assert.response(res).has.status(200)

      local logs = helpers.get_plugin_log("log-shared-context", "access_entity_credential_test_data")
      assert.is_table(logs)

      assert.are.same(key_auth_credential.key, logs[expected_output_key_key])
      assert.are.same(consumer.id, logs[expected_output_key_consumer_id]) -- Consumer ID from the credential
      assert.are.same(expected_default_value, logs[expected_output_key_nonexistent])
    end)
  end)
end)
