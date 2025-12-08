-- unittests/json-threat-protection/handler_spec.lua

describe("json-threat-protection handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should allow a valid json body", function()
    local handler = require "apigee-policies-based-plugins.json-threat-protection.handler"
    local conf = {
      max_depth = 10,
      max_array_elements = 100,
      max_string_length = 1000
    }

    spy.on(kong.request, "get_raw_body", function() return '{"a": 1}' end)
    local exited = spy.on(kong.response, "exit")
    
    handler:access(conf)

    assert.spy(exited).was.not_called()
  end)

  it("should block a json body with excessive depth", function()
    local handler = require "apigee-policies-based-plugins.json-threat-protection.handler"
    local conf = {
      max_depth = 2
    }

    spy.on(kong.request, "get_raw_body", function() return '{"a":{"b":{"c":1}}}' end)
    local exited = spy.on(kong.response, "exit")
    
    handler:access(conf)

    assert.spy(exited).was.called()
  end)
end)
