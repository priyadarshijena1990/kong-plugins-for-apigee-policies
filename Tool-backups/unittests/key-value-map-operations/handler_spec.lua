-- unittests/key-value-map-operations/handler_spec.lua

describe("key-value-map-operations handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should put a value in the map", function()
    local handler = require "apigee-policies-based-plugins.key-value-map-operations.handler"
    local conf = {
      map_name = "my-map",
      operation = "put",
      key = "my-key",
      value_source = "literal",
      value = "my-value"
    }

    local set = spy.on(kong.vault, "put")
    
    handler:access(conf)

    assert.spy(set).was.called_with("my-map", "my-key", "my-value")
  end)

  it("should get a value from the map", function()
    local handler = require "apigee-policies-based-plugins.key-value-map-operations.handler"
    local conf = {
      map_name = "my-map",
      operation = "get",
      key = "my-key",
      output_variable = "my_value"
    }

    spy.on(kong.vault, "get", function() return "my-value" end)
    
    handler:access(conf)

    assert.equal("my-value", kong.ctx.shared.my_value)
  end)
end)
