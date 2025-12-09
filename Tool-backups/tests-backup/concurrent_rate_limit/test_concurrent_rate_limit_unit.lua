-- Unit tests for concurrent-rate-limit plugin
local handler = require("kong.plugins.concurrent-rate-limit.handler")

-- Test: new()
local instance = handler:new()
assert(instance ~= nil, "Handler instance should be created")

-- Test: access() with valid header key
local conf = {
  rate = 1,
  counter_key_source_type = "header",
  counter_key_source_name = "X-User"
}
local kong = {
  shared = { concurrent_limit_counters = { ["user1"] = 0 } },
  request = { get_header = function(name) return "user1" end },
  ctx = { shared = {} },
  log = { err = print, warn = print },
  response = { exit = function() error("Should not exit") end }
}
instance:access(conf)
