-- unittests/decode-jwt/functional_spec.lua

describe("decode-jwt functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should decode JWT and extract claims", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("decode-jwt")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    bp.plugins:insert({
      name = "decode-jwt",
      route = { id = route.id },
      config = {
        jwt_source_type = "header",
        jwt_source_name = "x-jwt",
        claims_to_extract = {
          { claim_name = "sub", output_key = "subject" }
        }
      },
    })

    bp.plugins:insert({
      name = "mock-downstream",
      route = { id = route.id },
    })

    -- A valid JWT with payload {"sub":"123"}
    local jwt_string = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjMifQ.fl8uQXs-Tii6582Z2ctyVwF3M5j5a7j29Hh_f4p-rU8"

    local r = bp.proxy:send {
      method = "GET",
      host = "example.com",
      path = "/",
      headers = {
        ["x-jwt"] = jwt_string
      }
    }

    assert.equal(200, r.status)
    assert.equal("123", r.headers["X-Subject"])
  end)
end)
