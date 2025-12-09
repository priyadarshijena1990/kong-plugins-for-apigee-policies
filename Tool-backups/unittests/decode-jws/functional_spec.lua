-- unittests/decode-jws/functional_spec.lua

describe("decode-jws functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should decode JWS and extract claims", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("decode-jws")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    -- Mock JWS decoding service
    local jws_decode_service = bp.services:insert({
      url = "http://localhost:12345"
    })
    local jws_decode_route = bp.routes:insert({
      hosts = { "jws-decode-service" },
      paths = { "/" },
      service = jws_decode_service
    })
    bp.plugins:insert({
      name = "request-transformer",
      route = { id = jws_decode_route.id },
      config = {
        replace = {
          body = '{"payload": {"sub": "123"}}'
        }
      }
    })

    bp.plugins:insert({
      name = "decode-jws",
      route = { id = route.id },
      config = {
        jws_decode_service_url = "http://jws-decode-service/",
        jws_source_type = "header",
        jws_source_name = "x-jws",
        public_key_source_type = "literal",
        public_key_literal = "mykey",
        claims_to_extract = {
          { claim_name = "sub", output_key = "subject" }
        }
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
        ["x-jws"] = "myjws"
      }
    }

    assert.equal(200, r.status)
    assert.equal("123", r.headers["X-Subject"])
  end)
end)
