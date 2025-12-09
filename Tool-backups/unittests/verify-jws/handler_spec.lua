-- unittests/verify-jws/handler_spec.lua

describe("verify-jws handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should verify a JWS", function()
    local handler = require "apigee-policies-based-plugins.verify-jws.handler"
    local conf = {
      jws_source_type = "header",
      jws_source_name = "x-jws",
      public_key_source_type = "literal",
      public_key_literal = "mykey",
      on_error_continue = true
    }
    
    spy.on(kong.request, "get_header", function(name)
      if name == "x-jws" then return "myjws" end
    end)
    local request_spy = spy.on(kong.http.client, "request", function()
      return { status = 200, body = "{}" }
    end)
    
    handler:access(conf)

    assert.spy(request_spy).was.called()
  end)
end)
