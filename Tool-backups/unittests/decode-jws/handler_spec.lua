-- unittests/decode-jws/handler_spec.lua

describe("decode-jws handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should get JWS from header", function()
    local handler = require "apigee-policies-based-plugins.decode-jws.handler"
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
    spy.on(kong.http.client, "request", function()
      return { status = 200, body = "{}" }
    end)
    
    handler:access(conf)
    assert.spy(kong.http.client.request).was.called()
  end)

  it("should extract claims", function()
    local handler = require "apigee-policies-based-plugins.decode-jws.handler"
    local conf = {
      jws_source_type = "header",
      jws_source_name = "x-jws",
      public_key_source_type = "literal",
      public_key_literal = "mykey",
      claims_to_extract = {
        { claim_name = "sub", output_key = "subject" }
      },
      on_error_continue = true
    }
    
    spy.on(kong.request, "get_header", function(name)
      if name == "x-jws" then return "myjws" end
    end)
    spy.on(kong.http.client, "request", function()
      return { status = 200, body = '{"payload": {"sub": "123"}}' }
    end)
    
    handler:access(conf)
    assert.equal("123", kong.ctx.shared.subject)
  end)
end)
