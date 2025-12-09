-- unittests/set-integration-request/handler_spec.lua

describe("set-integration-request handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should set the integration request", function()
    local handler = require "apigee-policies-based-plugins.set-integration-request.handler"
    local conf = {
      service_name = "my-service",
      path = "/get",
      method = "GET"
    }

    spy.on(kong.db.services, "select_by_name", function() return { id = "123" } end)
    local set_upstream_spy = spy.on(kong.service, "set_upstream")
    
    handler:access(conf)

    assert.spy(set_upstream_spy).was.called()
  end)
end)
