-- unittests/xsltransform/handler_spec.lua

describe("xsltransform handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should transform xml", function()
    local handler = require "apigee-policies-based-plugins.xsltransform.handler"
    local conf = {
      source = "request",
      xsl = "<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'><xsl:template match='/'><root/></xsl:template></xsl:stylesheet>",
      output_variable = "transformed_body"
    }

    spy.on(kong.request, "get_raw_body", function() return "<root><a>1</a></root>" end)
    
    handler:access(conf)

    assert.is_not_nil(kong.ctx.shared.transformed_body)
    assert.matches("<root/>", kong.ctx.shared.transformed_body, nil, true)
  end)
end)
