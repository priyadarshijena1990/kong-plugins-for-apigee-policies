-- unittests/graphql/handler_spec.lua

describe("graphql handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should process a graphql query", function()
    local handler = require "apigee-policies-based-plugins.graphql.handler"
    local conf = {
      endpoint = "/graphql",
      query = "{ me { name } }",
      variables = {}
    }

    local request_spy = spy.on(kong.http.client, "request", function()
      return { status = 200, body = "{}" }
    end)
    
    handler:access(conf)

    assert.spy(request_spy).was.called()
  end)
end)
