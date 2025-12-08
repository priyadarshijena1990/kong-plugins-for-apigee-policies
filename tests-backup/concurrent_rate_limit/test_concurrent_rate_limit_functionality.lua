-- Test Case 1: Allow request under limit
local handler = require("kong.plugins.concurrent-rate-limit.handler")
local conf = {
  rate = 2,
  counter_key_source_type = "header",
  counter_key_source_name = "X-User",
  on_limit_exceeded_status = 429,
  on_limit_exceeded_body = "Rate limit exceeded"
}
local kong = {
  shared = { concurrent_limit_counters = { ["user1"] = 1 } },
  request = { get_header = function(name) return "user1" end },
  ctx = { shared = {} },
  log = { err = print, warn = print },
  response = { exit = function() error("Should not exit") end }
}
handler:access(conf)

-- Test Case 2: Exceed limit, fault raised
kong.shared.concurrent_limit_counters["user1"] = 2
kong.response.exit = function(status, body)
  assert(status == 429)
  assert(body == "Rate limit exceeded")
end
handler:access(conf)

-- Test Case 3: Use global key when header missing
kong.request.get_header = function(name) return nil end
kong.shared.concurrent_limit_counters["global"] = 0
kong.response.exit = function(status, body)
  error("Should not exit")
end
handler:access(conf)
