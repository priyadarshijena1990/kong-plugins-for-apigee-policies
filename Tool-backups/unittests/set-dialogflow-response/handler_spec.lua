-- unittests/set-dialogflow-response/handler_spec.lua

describe("set-dialogflow-response handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {
          dialogflow_response = {
            fulfillmentText = "hello"
          }
        }
      }
    })
  end)

  it("should set the dialogflow response", function()
    local handler = require "apigee-policies-based-plugins.set-dialogflow-response.handler"
    local conf = {
      source = "dialogflow_response"
    }

    local set_body = spy.on(kong.response, "set_body")
    
    handler:access(conf)

    assert.spy(set_body).was.called()
  end)
end)
