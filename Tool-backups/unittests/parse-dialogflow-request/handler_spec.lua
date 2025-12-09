-- unittests/parse-dialogflow-request/handler_spec.lua

describe("parse-dialogflow-request handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should parse a dialogflow request", function()
    local handler = require "apigee-policies-based-plugins.parse-dialogflow-request.handler"
    local conf = {
      output_variable = "dialogflow_request"
    }

    spy.on(kong.request, "get_raw_body", function() return '{"queryResult": {"queryText": "hello"}}' end)
    
    handler:access(conf)

    assert.is_not_nil(kong.ctx.shared.dialogflow_request)
    assert.equal("hello", kong.ctx.shared.dialogflow_request.queryResult.queryText)
  end)
end)
