-- unittests/read-property-set/handler_spec.lua

describe("read-property-set handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should read a property set", function()
    local handler = require "apigee-policies-based-plugins.read-property-set.handler"
    local conf = {
      property_set = "my-properties",
      output_variable = "my_props"
    }

    spy.on(kong.vault, "get", function() return '{"a":1}' end)
    
    handler:access(conf)

    assert.is_not_nil(kong.ctx.shared.my_props)
    assert.equal(1, kong.ctx.shared.my_props.a)
  end)
end)
