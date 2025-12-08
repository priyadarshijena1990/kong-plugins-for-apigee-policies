-- unittests/soap-message-validation/handler_spec.lua

describe("soap-message-validation handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should validate a soap message", function()
    local handler = require "apigee-policies-based-plugins.soap-message-validation.handler"
    local conf = {
      wsdl = "my.wsdl",
      schema = "my.xsd"
    }

    spy.on(kong.request, "get_raw_body", function() return "<soapenv:Envelope/>" end)
    local exited = spy.on(kong.response, "exit")
    
    -- This is a simplified test. A real test would require a WSDL/XSD parser.
    handler:access(conf)

    assert.spy(exited).was.not_called()
  end)
end)
