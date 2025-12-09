-- unittests/flow-callout/handler_spec.lua

describe("flow-callout handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should make a successful flow callout", function()
    local handler = require "apigee-policies-based-plugins.flow-callout.handler"
    local conf = {
      shared_flow_service_name = "my-flow",
      preserve_original_request_body = true,
      on_flow_error_continue = false
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

  it("should handle flow callout failure", function()
    local handler = require "apigee-policies-based-plugins.flow-callout.handler"
    local conf = {
      shared_flow_service_name = "my-flow",
      on_flow_error_continue = false,
      on_flow_error_status = 500,
      on_flow_error_body = "Flow failed"
    }

    spy.on(kong.db.services, "select_by_name", function() return nil, "not found" end)
    local exited = spy.on(kong.response, "exit")
    
    handler:access(conf)

    assert.spy(exited).was.called_with(500, "Flow failed")
  end)
end)
