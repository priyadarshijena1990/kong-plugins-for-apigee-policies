-- unittests/revoke-oauth-v2/handler_spec.lua

describe("revoke-oauth-v2 handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should revoke an oauth2 token", function()
    local handler = require "apigee-policies-based-plugins.revoke-oauth-v2.handler"
    local conf = {
      token_source = "request"
    }

    spy.on(kong.request, "get_post_arg", function(name)
      if name == "token" then return "mytoken" end
    end)
    local deleted = spy.on(kong.db.oauth2_tokens, "delete")
    
    handler:access(conf)

    assert.spy(deleted).was.called()
  end)
end)
