-- unittests/xml-to-json/handler_spec.lua

describe("xml-to-json handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should convert xml to json", function()
    local handler = require "apigee-policies-based-plugins.xml-to-json.handler"
    local conf = {
      source = "request",
      output_variable = "json_body"
    }

    spy.on(kong.request, "get_raw_body", function() return "<root><a>1</a></root>" end)
    
    handler:access(conf)

    assert.is_not_nil(kong.ctx.shared.json_body)
    assert.matches('{"root":{"a":"1"}}', kong.ctx.shared.json_body, nil, true)
  end)
end)
