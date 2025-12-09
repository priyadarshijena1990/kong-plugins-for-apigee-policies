-- unittests/assert-condition/functional_spec.lua

describe("assert-condition functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should allow request if condition is true", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("assert-condition")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    bp.plugins:insert({
      name = "assert-condition",
      route = { id = route.id },
      config = {
        condition = "kong.request.get_header('x-my-header') == 'my-value'",
        on_false_action = "abort",
        abort_status = 403,
        abort_message = "Forbidden"
      },
    })

    local r = bp.proxy:send {
      method = "GET",
      host = "example.com",
      path = "/",
      headers = {
        ["x-my-header"] = "my-value"
      }
    }

    assert.equal(200, r.status)
  end)

  it("should abort request if condition is false", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("assert-condition")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    bp.plugins:insert({
      name = "assert-condition",
      route = { id = route.id },
      config = {
        condition = "kong.request.get_header('x-my-header') == 'my-value'",
        on_false_action = "abort",
        abort_status = 403,
        abort_message = "Forbidden"
      },
    })

    local r = bp.proxy:send {
      method = "GET",
      host = "example.com",
      path = "/",
      headers = {
        ["x-my-header"] = "another-value"
      }
    }

    assert.equal(403, r.status)
    assert.matches("Forbidden", r.body, nil, true)
  end)
end)
