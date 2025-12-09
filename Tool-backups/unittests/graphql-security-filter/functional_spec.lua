-- unittests/graphql-security-filter/functional_spec.lua

describe("graphql-security-filter functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should allow a valid query", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("graphql-security-filter")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    bp.plugins:insert({
      name = "graphql-security-filter",
      route = { id = route.id },
      config = {
        max_depth = 10,
        max_complexity = 1000
      },
    })

    local r = bp.proxy:send {
      method = "POST",
      host = "example.com",
      path = "/",
      headers = {
        ["Content-Type"] = "application/json"
      },
      body = '{"query":"{ me { name } }"}'
    }

    assert.equal(200, r.status)
  end)

  it("should block a query with excessive depth", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("graphql-security-filter")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    bp.plugins:insert({
      name = "graphql-security-filter",
      route = { id = route.id },
      config = {
        max_depth = 2
      },
    })

    local r = bp.proxy:send {
      method = "POST",
      host = "example.com",
      path = "/",
      headers = {
        ["Content-Type"] = "application/json"
      },
      body = '{"query":"{ me { friends { friends { name } } } }"}'
    }

    assert.equal(400, r.status)
  end)
end)
