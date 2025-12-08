-- unittests/invalidate-cache/functional_spec.lua

describe("invalidate-cache functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should invalidate a cache key", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("invalidate-cache")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    -- set a value in cache
    local cache = require "kong.cache"
    cache.set("my-cache-key", "my-value")

    bp.plugins:insert({
      name = "invalidate-cache",
      route = { id = route.id },
      config = {
        cache_key = "my-cache-key"
      },
    })

    local r = bp.proxy:send {
      method = "GET",
      host = "example.com",
      path = "/",
    }

    assert.equal(200, r.status)

    local val = cache.get("my-cache-key")
    assert.is_nil(val)
  end)
end)
