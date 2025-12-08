-- unittests/json-threat-protection/functional_spec.lua

describe("json-threat-protection functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should allow a valid json body", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("json-threat-protection")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/post",
      }),
    })

    bp.plugins:insert({
      name = "json-threat-protection",
      route = { id = route.id },
      config = {
        max_depth = 10,
        max_array_elements = 100,
        max_string_length = 1000
      },
    })

    local r = bp.proxy:send {
      method = "POST",
      host = "example.com",
      path = "/",
      headers = {
        ["Content-Type"] = "application/json"
      },
      body = '{"a": 1}'
    }

    assert.equal(200, r.status)
  end)

  it("should block a json body with excessive depth", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("json-threat-protection")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/post",
      }),
    })

    bp.plugins:insert({
      name = "json-threat-protection",
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
      body = '{"a":{"b":{"c":1}}}'
    }

    assert.equal(400, r.status)
  end)
end)
