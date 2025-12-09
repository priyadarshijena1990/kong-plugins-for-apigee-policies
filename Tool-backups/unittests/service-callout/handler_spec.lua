-- unittests/service-callout/handler_spec.lua

describe("service-callout handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should make a successful callout", function()
    local handler = require "apigee-policies-based-plugins.service-callout.handler"
    local conf = {
      service_name = "my-service",
      path = "/get",
      method = "GET"
    }

    spy.on(kong.db.services, "select_by_name", function() return { id = "123" } end)
    local request_spy = spy.on(kong.service.request, "new", function()
      return {
        send = function()
          return { status = 200, body = "response body", headers = {} }
        end
      }
    end)
    
    handler:access(conf)

    assert.spy(request_spy).was.called()
  end)
end)
