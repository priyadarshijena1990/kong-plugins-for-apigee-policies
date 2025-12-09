-- unittests/semantic-cache-populate/handler_spec.lua

describe("semantic-cache-populate handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should populate the cache", function()
    local handler = require "apigee-policies-based-plugins.semantic-cache-populate.handler"
    local conf = {
      cache_key = "my-cache-key",
      value_source = "literal",
      value = "my-value"
    }

    local set = spy.on(kong.cache, "set")
    
    handler:access(conf)

    assert.spy(set).was.called_with("my-cache-key", "my-value")
  end)
end)
