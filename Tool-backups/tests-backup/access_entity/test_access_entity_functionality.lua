-- Test Case 1: Extract consumer username
local handler = require("kong.plugins.access-entity.handler")
local conf = {
  entity_type = "consumer",
  extract_attributes = {
    { source_field = "username", output_key = "user_name" }
  }
}
local kong = { client = { get_consumer = function() return { username = "test_user" } end }, ctx = { shared = {} }, log = { debug = print, warn = print } }
handler:access(conf)
assert(kong.ctx.shared["user_name"] == "test_user")

-- Test Case 2: Extract credential key
local conf2 = {
  entity_type = "credential",
  extract_attributes = {
    { source_field = "key", output_key = "api_key" }
  }
}
kong.client.get_credential = function() return { key = "my-api-key" } end
handler:access(conf2)
assert(kong.ctx.shared["api_key"] == "my-api-key")

-- Test Case 3: Default value fallback
local conf3 = {
  entity_type = "consumer",
  extract_attributes = {
    { source_field = "nonexistent", output_key = "fallback", default_value = "default" }
  }
}
kong.client.get_consumer = function() return { username = "test_user" } end
handler:access(conf3)
assert(kong.ctx.shared["fallback"] == "default")
