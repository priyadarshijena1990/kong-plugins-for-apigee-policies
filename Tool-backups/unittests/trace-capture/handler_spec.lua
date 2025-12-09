-- unittests/trace-capture/handler_spec.lua

describe("trace-capture handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should capture trace information", function()
    local handler = require "apigee-policies-based-plugins.trace-capture.handler"
    local conf = {
      output_variable = "trace_info"
    }
    
    handler:access(conf)

    assert.is_not_nil(kong.ctx.shared.trace_info)
  end)
end)
