-- unittests/external-callout/handler_spec.lua

describe("external-callout handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should make a successful callout and store response", function()
    local handler = require "apigee-policies-based-plugins.external-callout.handler"
    local conf = {
      callout_url = "http://example.com",
      method = "POST",
      wait_for_response = true,
      response_to_shared_context_key = "callout_response",
      on_error_continue = false
    }

    spy.on(kong.request, "get_raw_body", function() return "request body" end)
    local request_spy = spy.on(kong.http.client, "request", function()
      return { status = 200, body = "response body", headers = {} }
    end)
    
    handler:access(conf)

    assert.spy(request_spy).was.called()
    assert.is_not_nil(kong.ctx.shared.callout_response)
    assert.equal(200, kong.ctx.shared.callout_response.status)
    assert.equal("response body", kong.ctx.shared.callout_response.body)
  end)

  it("should handle callout failure", function()
    local handler = require "apigee-policies-based-plugins.external-callout.handler"
    local conf = {
      callout_url = "http://example.com",
      method = "POST",
      wait_for_response = true,
      on_error_continue = false,
      on_error_status = 500,
      on_error_body = "Callout failed"
    }

    spy.on(kong.http.client, "request", function()
      return nil, "error"
    end)
    local exited = spy.on(kong.response, "exit")
    
    handler:access(conf)

    assert.spy(exited).was.called_with(500, "Callout failed")
  end)
end)
