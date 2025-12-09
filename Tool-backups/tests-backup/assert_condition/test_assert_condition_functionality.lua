-- Test Case 1: Condition true, request proceeds
local handler = require("kong.plugins.assert-condition.handler")
local conf = {
  lua_condition = "kong.ctx.shared.is_valid == true",
  on_assertion_failure_status = 400,
  on_assertion_failure_body = "Assertion failed",
  on_assertion_failure_headers = { ["X-Error"] = "Failed" }
}
local kong = { ctx = { shared = { is_valid = true } }, log = { err = print, warn = print }, response = { exit = function() error("Should not exit") end } }
handler:access(conf)

-- Test Case 2: Condition false, fault raised
local conf2 = {
  lua_condition = "kong.ctx.shared.is_valid == true",
  on_assertion_failure_status = 401,
  on_assertion_failure_body = "Unauthorized",
  on_assertion_failure_headers = { ["X-Error"] = "Unauthorized" }
}
kong.ctx.shared.is_valid = false
local exited = false
kong.response.exit = function(status, body)
  exited = true
  assert(status == 401)
  assert(body == "Unauthorized")
end
handler:access(conf2)
assert(exited, "Should exit with fault when condition is false")

-- Test Case 3: Invalid Lua condition, config error
local conf3 = {
  lua_condition = "invalid_lua_code!",
  on_assertion_failure_status = 500,
  on_assertion_failure_body = "Config error"
}
kong.response.exit = function(status, body)
  assert(status == 500)
  assert(body:find("Internal Server Error"))
end
handler:access(conf3)
