-- unittests/generate-jws/handler_spec.lua

describe("generate-jws handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should generate a JWS and set it in the header", function()
    local handler = require "apigee-policies-based-plugins.generate-jws.handler"
    local conf = {
      payload_source_type = "literal",
      payload_source_name = '{"sub":"123"}',
      private_key_source_type = "literal",
      private_key_literal = "my-secret-key",
      algorithm = "HS256",
      output_destination_type = "header",
      output_destination_name = "x-jws",
      on_error_continue = false
    }

    local set_header_spy = spy.on(kong.request, "set_header")
    
    handler:access(conf)

    assert.spy(set_header_spy).was.called()
  end)

  it("should generate a JWS and set it in the body", function()
    local handler = require "apigee-policies-based-plugins.generate-jws.handler"
    local conf = {
      payload_source_type = "literal",
      payload_source_name = '{"sub":"123"}',
      private_key_source_type = "literal",
      private_key_literal = "my-secret-key",
      algorithm = "HS256",
      output_destination_type = "body",
      output_destination_name = "jws",
      on_error_continue = false
    }

    local set_body_spy = spy.on(kong.request, "set_body")
    
    handler:access(conf)

    assert.spy(set_body_spy).was.called()
  end)
end)
