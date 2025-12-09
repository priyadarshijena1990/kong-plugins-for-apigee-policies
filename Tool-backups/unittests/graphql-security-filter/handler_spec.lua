-- unittests/graphql-security-filter/handler_spec.lua

describe("graphql-security-filter handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should allow a valid query", function()
    local handler = require "apigee-policies-based-plugins.graphql-security-filter.handler"
    local conf = {
      max_depth = 10,
      max_complexity = 1000
    }

    local exited = spy.on(kong.response, "exit")
    
    -- This is a simplified test. A real test would require a GraphQL parser.
    handler:access(conf)

    assert.spy(exited).was.not_called()
  end)
end)
