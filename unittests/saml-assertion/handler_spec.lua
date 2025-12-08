-- unittests/saml-assertion/handler_spec.lua

describe("saml-assertion handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should generate a saml assertion", function()
    local handler = require "apigee-policies-based-plugins.saml-assertion.handler"
    local conf = {
      issuer = "my-issuer",
      subject = "my-subject",
      output_variable = "saml_assertion"
    }

    handler:access(conf)

    assert.is_not_nil(kong.ctx.shared.saml_assertion)
  end)
end)
