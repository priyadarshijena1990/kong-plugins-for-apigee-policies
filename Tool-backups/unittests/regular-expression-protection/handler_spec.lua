-- unittests/regular-expression-protection/handler_spec.lua

describe("regular-expression-protection handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should allow a valid input", function()
    local handler = require "apigee-policies-based-plugins.regular-expression-protection.handler"
    local conf = {
      patterns = { "a.c" }
    }

    spy.on(kong.request, "get_raw_body", function() return "abc" end)
    local exited = spy.on(kong.response, "exit")
    
    handler:access(conf)

    assert.spy(exited).was.not_called()
  end)

  it("should block an invalid input", function()
    local handler = require "apigee-policies-based-plugins.regular-expression-protection.handler"
    local conf = {
      patterns = { "a.c" }
    }

    spy.on(kong.request, "get_raw_body", function() return "abd" end)
    local exited = spy.on(kong.response, "exit")
    
    handler:access(conf)

    assert.spy(exited).was.called()
  end)
end)
