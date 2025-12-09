-- unittests/semantic-cache-lookup/handler_spec.lua

describe("semantic-cache-lookup handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should lookup a value in the cache", function()
    local handler = require "apigee-policies-based-plugins.semantic-cache-lookup.handler"
    local conf = {
      cache_key = "my-cache-key",
      output_variable = "my_value"
    }

    spy.on(kong.cache, "get", function() return "my-value" end)
    
    handler:access(conf)

    assert.equal("my-value", kong.ctx.shared.my_value)
  end)
end)
