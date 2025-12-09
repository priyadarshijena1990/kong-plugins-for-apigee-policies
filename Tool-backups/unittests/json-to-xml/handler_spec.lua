-- unittests/json-to-xml/handler_spec.lua

describe("json-to-xml handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should convert json to xml", function()
    local handler = require "apigee-policies-based-plugins.json-to-xml.handler"
    local conf = {
      source = "request",
      output_variable = "xml_body"
    }

    spy.on(kong.request, "get_raw_body", function() return '{"a": 1}' end)
    
    handler:access(conf)

    assert.is_not_nil(kong.ctx.shared.xml_body)
    assert.matches("<root><a>1</a></root>", kong.ctx.shared.xml_body, nil, true)
  end)
end)
