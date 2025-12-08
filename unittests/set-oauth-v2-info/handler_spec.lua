-- unittests/set-oauth-v2-info/handler_spec.lua

describe("set-oauth-v2-info handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should set oauth2 info", function()
    local handler = require "apigee-policies-based-plugins.set-oauth-v2-info.handler"
    local conf = {
      consumer_id = "my-consumer",
      token = "my-token"
    }

    local insert = spy.on(kong.db.oauth2_tokens, "insert")
    
    handler:access(conf)

    assert.spy(insert).was.called()
  end)
end)
