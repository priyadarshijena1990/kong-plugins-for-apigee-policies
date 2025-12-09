-- unittests/access-entity/functional_spec.lua

describe("access-entity functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should store consumer details in ctx.shared and be accessible by downstream plugin", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("access-entity")

    local consumer = bp.consumers:insert({
      username = "testuser",
    })

    bp.consumers:add_to_group(consumer, "group1")
    bp.consumers:add_to_group(consumer, "group2")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    bp.plugins:insert({
      name = "access-entity",
      route = { id = route.id },
      config = {
        context_variable_name = "consumer_entity",
      },
    })

    bp.plugins:insert({
      name = "mock-downstream",
      route = { id = route.id },
    })

    local r = bp.proxy:send {
      method = "GET",
      host = "example.com",
      path = "/",
      headers = {
        ["apikey"] = consumer.keyauth_credentials:insert().key,
      },
    }

    assert.equal(200, r.status)
    assert.equal(consumer.id, r.headers["X-Consumer-Id"])
    assert.equal(consumer.username, r.headers["X-Consumer-Username"])
    assert.equal("group1,group2", r.headers["X-Consumer-Groups"])
  end)
end)
