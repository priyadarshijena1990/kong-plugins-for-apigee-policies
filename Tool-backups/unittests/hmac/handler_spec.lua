-- unittests/hmac/handler_spec.lua

describe("hmac handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should generate an hmac", function()
    local handler = require "apigee-policies-based-plugins.hmac.handler"
    local conf = {
      algorithm = "hmac-sha256",
      key = "my-secret-key",
      message = "my-message",
      output_variable = "hmac_value"
    }

    handler:access(conf)

    assert.is_not_nil(kong.ctx.shared.hmac_value)
  end)
end)
