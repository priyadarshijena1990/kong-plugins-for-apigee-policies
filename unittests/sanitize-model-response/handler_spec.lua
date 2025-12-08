-- unittests/sanitize-model-response/handler_spec.lua

describe("sanitize-model-response handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should sanitize a model response", function()
    local handler = require "apigee-policies-based-plugins.sanitize-model-response.handler"
    local conf = {
      rules = {
        {
          pattern = "credit-card",
          replacement = "****"
        }
      }
    }

    spy.on(kong.service.response, "get_raw_body", function() return "1234-5678-9012-3456" end)
    local set_body = spy.on(kong.service.response, "set_body")

    handler:response(conf)

    assert.spy(set_body).was.called_with("****")
  end)
end)
