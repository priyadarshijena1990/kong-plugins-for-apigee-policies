local helpers = require("spec.helpers")
local busted = require("busted.runner")()
local assert = busted.assert
local inspect = require("inspect")
local cjson = require("cjson")

describe("Plugin: read-property-set", function()

  local client
  local service

  before_each(function()
    -- Create a service to attach the plugin to
    service = helpers.dao.services:insert {
      name = "my-service",
      host = helpers.mock_upstream_host,
      port = helpers.mock_upstream_port,
    }

    -- Create a route for the service
    helpers.dao.routes:insert {
      hosts = { "read-property-set.com" },
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

  describe("Scenario 1: Assign entire PropertySet to a single shared context key", function()
    local expected_properties = {
      api_key = "test_api_key_123",
      service_url = "https://mock.example.com",
      debug_mode = "true"
    }
    local shared_context_key = "global_config"
    local property_set_name = "MyGlobalConfig"

    before_each(function()
      assert(helpers.start_kong({
        -- Enable the plugin on the service
        plugins = {
          {
            name = "read-property-set",
            service = service,
            config = {
              property_set_name = property_set_name,
              properties = expected_properties,
              assign_to_shared_context_key = shared_context_key,
            }
          },
          { -- Add a helper plugin to capture kong.ctx.shared
            name = "log-shared-context",
            service = service,
            config = {
              log_key = "read_property_set_test_data",
              target_key_prefix = shared_context_key -- Capture the specific key
            }
          }
        }
      }))
    end)

    it("should store the entire PropertySet map in the specified shared context key", function()
      local res = client:get("/", { headers = { host = "read-property-set.com" } })
      assert.response(res).has.status(200)

      -- Retrieve the logs from the log-shared-context plugin
      local logs = helpers.get_plugin_log("log-shared-context", "read_property_set_test_data")
      assert.is_table(logs)
      
      -- The log-shared-context plugin will store the *value* of the key in shared context,
      -- which for a map is directly the map.
      -- The log-shared-context plugin stores string representation (cjson.encode), so decode back to check
      local stored_map_json = logs[shared_context_key]
      assert.is_string(stored_map_json)
      local stored_map = cjson.decode(stored_map_json)

      assert.is_table(stored_map)
      assert.are.same(expected_properties, stored_map)
    end)
  end)

  describe("Scenario 2: Assign individual properties with prefix", function()
    local expected_properties = {
      feature_x_enabled = "true",
      variant = "A"
    }
    local property_set_name = "FeatureFlags"

    before_each(function()
      assert(helpers.start_kong({
        -- Enable the plugin on the service
        plugins = {
          {
            name = "read-property-set",
            service = service,
            config = {
              property_set_name = property_set_name,
              properties = expected_properties,
            }
          },
          { -- Add a helper plugin to capture kong.ctx.shared
            name = "log-shared-context",
            service = service,
            config = {
              log_key = "read_property_set_test_data",
              target_key_prefix = property_set_name .. "." -- Capture keys starting with prefix
            }
          }
        }
      }))
    end)

    it("should store individual properties prefixed by property_set_name", function()
      local res = client:get("/", { headers = { host = "read-property-set.com" } })
      assert.response(res).has.status(200)

      -- Retrieve the logs from the log-shared-context plugin
      local logs = helpers.get_plugin_log("log-shared-context", "read_property_set_test_data")
      assert.is_table(logs)

      assert.are.same(expected_properties.feature_x_enabled, logs[property_set_name .. ".feature_x_enabled"])
      assert.are.same(expected_properties.variant, logs[property_set_name .. ".variant"])
    end)
  end)
end)
