-- unittests/delete-oauth-v2-info/handler_spec.lua

describe("delete-oauth-v2-info handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should delete token from db", function()
    local handler = require "apigee-policies-based-plugins.delete-oauth-v2-info.handler"
    local conf = {
      token_source_type = "header",
      token_source_name = "x-token",
      on_error_continue = false
    }

    spy.on(kong.request, "get_header", function(name)
      if name == "x-token" then return "mytoken" end
    end)
    
    local deleted = spy.on(kong.db.oauth2_tokens, "delete")
    
    handler:access(conf)
    
    assert.spy(deleted).was.called_with({ access_token = "mytoken" })
  end)

  it("should continue on error if configured", function()
    local handler = require "apigee-policies-based-plugins.delete-oauth-v2-info.handler"
    local conf = {
      token_source_type = "header",
      token_source_name = "x-token",
      on_error_continue = true
    }

    spy.on(kong.request, "get_header", function(name)
      if name == "x-token" then return "mytoken" end
    end)
    
    spy.on(kong.db.oauth2_tokens, "delete", function() return nil, "db error" end)
    local exited = spy.on(kong.response, "exit")
    
    handler:access(conf)
    
    assert.spy(exited).was.not_called()
  end)
end)
