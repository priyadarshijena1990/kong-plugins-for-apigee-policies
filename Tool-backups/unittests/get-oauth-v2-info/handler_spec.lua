-- unittests/get-oauth-v2-info/handler_spec.lua

describe("get-oauth-v2-info handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should get oauth2 info and store it in ctx.shared", function()
    local handler = require "apigee-policies-based-plugins.get-oauth-v2-info.handler"
    local conf = {
      token_source_type = "header",
      token_source_name = "x-token",
      output_context_variable = "oauth2_info"
    }

    spy.on(kong.request, "get_header", function(name)
      if name == "x-token" then return "mytoken" end
    end)
    
    spy.on(kong.db.oauth2_tokens, "find_one_by_key", function()
      return {
        id = "123",
        token = "mytoken",
        consumer_id = "abc"
      }
    end)
    
    handler:access(conf)

    assert.is_not_nil(kong.ctx.shared.oauth2_info)
    assert.equal("123", kong.ctx.shared.oauth2_info.id)
  end)
end)
