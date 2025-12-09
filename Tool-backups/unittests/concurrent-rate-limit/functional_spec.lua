-- unittests/concurrent-rate-limit/functional_spec.lua

describe("concurrent-rate-limit functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should enforce local rate limit", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("concurrent-rate-limit")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/delay/2",
      }),
    })

    bp.plugins:insert({
      name = "concurrent-rate-limit",
      route = { id = route.id },
      config = {
        policy = "local",
        rate = 1,
        counter_key_source_type = "path",
        counter_key_source_name = "/"
      },
    })

    local threads = {}
    for i = 1, 2 do
      threads[i] = ngx.thread.spawn(function()
        local r = bp.proxy:send {
          method = "GET",
          host = "example.com",
          path = "/",
        }
        return r.status
      end)
    end

    local statuses = {}
    for i = 1, 2 do
      local ok, status = ngx.thread.wait(threads[i])
      if ok then
        table.insert(statuses, status)
      end
    end
    
    table.sort(statuses)
    assert.same({200, 429}, statuses)
  end)
end)
