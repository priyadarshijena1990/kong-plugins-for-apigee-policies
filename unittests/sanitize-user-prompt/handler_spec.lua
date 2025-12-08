-- unittests/sanitize-user-prompt/handler_spec.lua

describe("sanitize-user-prompt handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should sanitize a user prompt", function()
    local handler = require "apigee-policies-based-plugins.sanitize-user-prompt.handler"
    local conf = {
      rules = {
        {
          pattern = "credit-card",
          replacement = "****"
        }
      }
    }

    spy.on(kong.request, "get_raw_body", function() return "1234-5678-9012-3456" end)
    local set_body = spy.on(kong.request, "set_body")

    handler:access(conf)

    assert.spy(set_body).was.called_with("****")
  end)
end)
