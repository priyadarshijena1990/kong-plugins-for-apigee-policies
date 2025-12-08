-- unittests/generate-jws/functional_spec.lua

describe("generate-jws functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should generate a JWS and add it to the request", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("generate-jws")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    bp.plugins:insert({
      name = "generate-jws",
      route = { id = route.id },
      config = {
        payload_source_type = "literal",
        payload_source_name = '{"sub":"123"}',
        private_key_source_type = "literal",
        private_key_literal = "my-secret-key",
        algorithm = "HS256",
        output_destination_type = "header",
        output_destination_name = "x-jws"
      },
    })

    bp.plugins:insert({
      name = "mock-downstream",
      route = { id = route.id },
    })
    
    -- Update mock-downstream to read the jws
    local handler_path = "apigee-policies-based-plugins/mock-downstream/handler.lua"
    local f = io.open(handler_path, "r")
    local content = f:read("*a")
    f:close()
    content = content .. [[
      kong.response.set_header("X-JWS", kong.request.get_header("x-jws"))
    ]]
    f = io.open(handler_path, "w")
    f:write(content)
    f:close()


    local r = bp.proxy:send {
      method = "GET",
      host = "example.com",
      path = "/",
    }

    assert.equal(200, r.status)
    assert.is_not_nil(r.headers["X-JWS"])
  end)
end)
