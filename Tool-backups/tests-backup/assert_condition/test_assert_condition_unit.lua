-- Unit tests for assert-condition plugin
local handler = require("kong.plugins.assert-condition.handler")

-- Test: new()
local instance = handler:new()
assert(instance ~= nil, "Handler instance should be created")

-- Test: access() with valid Lua condition
local conf = {
  lua_condition = "kong.ctx.shared.is_valid == true"
}
local kong = { ctx = { shared = { is_valid = true } }, log = { err = print, warn = print }, response = { exit = function() error("Should not exit") end } }
instance:access(conf)

-- Test: access() with invalid Lua condition
local conf2 = {
  lua_condition = "invalid_lua_code!"
}
kong.response.exit = function(status, body)
  assert(status == 500)
end
instance:access(conf2)
