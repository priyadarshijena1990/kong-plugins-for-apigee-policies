-- Unit tests for each function/behavior in access-entity plugin
local handler = require("kong.plugins.access-entity.handler")

-- Test: new()
local instance = handler:new()
assert(instance ~= nil, "Handler instance should be created")

-- Test: access() with valid consumer
local conf = {
  entity_type = "consumer",
  extract_attributes = {
    { source_field = "username", output_key = "user_name" }
  }
}
local kong = { client = { get_consumer = function() return { username = "test_user" } end }, ctx = { shared = {} }, log = { debug = print, warn = print } }
instance:access(conf)
assert(kong.ctx.shared["user_name"] == "test_user", "Should extract username from consumer")

-- Test: access() with missing field and default value
local conf2 = {
  entity_type = "consumer",
  extract_attributes = {
    { source_field = "nonexistent", output_key = "fallback", default_value = "default" }
  }
}
kong.client.get_consumer = function() return { username = "test_user" } end
instance:access(conf2)
assert(kong.ctx.shared["fallback"] == "default", "Should use default value if field missing")
