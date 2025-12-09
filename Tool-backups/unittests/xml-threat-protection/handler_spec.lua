-- unittests/xml-threat-protection/handler_spec.lua

describe("xml-threat-protection handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should allow a valid xml body", function()
    local handler = require "apigee-policies-based-plugins.xml-threat-protection.handler"
    local conf = {
      max_depth = 10
    }

    spy.on(kong.request, "get_raw_body", function() return "<root><a>1</a></root>" end)
    local exited = spy.on(kong.response, "exit")
    
    handler:access(conf)

    assert.spy(exited).was.not_called()
  end)

  it("should block an xml body with excessive depth", function()
    local handler = require "apigee-policies-based-plugins.xml-threat-protection.handler"
    local conf = {
      max_depth = 2
    }

    spy.on(kong.request, "get_raw_body", function() return "<root><a><b><c>1</c></b></a></root>" end)
    local exited = spy.on(kong.response, "exit")
    
    handler:access(conf)

    assert.spy(exited).was.called()
  end)
end)
