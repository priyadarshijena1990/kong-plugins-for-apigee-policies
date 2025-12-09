-- unittests/invalidate-cache/handler_spec.lua

describe("invalidate-cache handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should invalidate a cache key", function()
    local handler = require "apigee-policies-based-plugins.invalidate-cache.handler"
    local conf = {
      cache_key = "my-cache-key"
    }

    local invalidated = spy.on(kong.cache, "invalidate")
    
    handler:access(conf)

    assert.spy(invalidated).was.called_with("my-cache-key")
  end)
end)
