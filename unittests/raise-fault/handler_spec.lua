-- unittests/raise-fault/handler_spec.lua

describe("raise-fault handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should raise a fault", function()
    local handler = require "apigee-policies-based-plugins.raise-fault.handler"
    local conf = {
      status_code = 400,
      fault_string = "My fault"
    }

    local exited = spy.on(kong.response, "exit")
    
    handler:access(conf)

    assert.spy(exited).was.called_with(400, "My fault")
  end)
end)
