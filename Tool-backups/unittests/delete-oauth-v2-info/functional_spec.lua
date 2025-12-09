-- unittests/delete-oauth-v2-info/functional_spec.lua

describe("delete-oauth-v2-info functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should delete oauth2 token", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("delete-oauth-v2-info")

    local consumer = bp.consumers:insert()
    local token = consumer.oauth2_credentials:insert().access_token

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    bp.plugins:insert({
      name = "delete-oauth-v2-info",
      route = { id = route.id },
      config = {
        token_source_type = "header",
        token_source_name = "x-token"
      },
    })

    local r = bp.proxy:send {
      method = "GET",
      host = "example.com",
      path = "/",
      headers = {
        ["x-token"] = token
      }
    }

    assert.equal(200, r.status)

    local _, err = bp.db.oauth2_tokens:find_one_by_key(token)
    assert.is_not_nil(err)
    assert.equal("not found", err.message)
  end)
end)
