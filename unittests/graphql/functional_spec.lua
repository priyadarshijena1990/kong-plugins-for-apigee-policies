-- unittests/graphql/functional_spec.lua

describe("graphql functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should process a graphql query", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("graphql")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    -- Mock GraphQL service
    local graphql_service = bp.services:insert({
      url = "http://localhost:12345"
    })
    local graphql_route = bp.routes:insert({
      hosts = { "graphql-service" },
      paths = { "/" },
      service = graphql_service
    })
    bp.plugins:insert({
      name = "request-transformer",
      route = { id = graphql_route.id },
      config = {
        replace = {
          body = '{"data":{"me":{"name":"test"}}}'
        }
      }
    })

    bp.plugins:insert({
      name = "graphql",
      route = { id = route.id },
      config = {
        endpoint = "http://graphql-service/",
        query = "{ me { name } }",
        variables = {}
      },
    })

    local r = bp.proxy:send {
      method = "GET",
      host = "example.com",
      path = "/",
    }

    assert.equal(200, r.status)
    assert.matches('{"data":{"me":{"name":"test"}}}', r.body, nil, true)
  end)
end)
