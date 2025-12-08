-- unittests/hmac/functional_spec.lua

describe("hmac functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should generate an hmac", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("hmac")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    bp.plugins:insert({
      name = "hmac",
      route = { id = route.id },
      config = {
        algorithm = "hmac-sha256",
        key = "my-secret-key",
        message = "my-message",
        output_variable = "hmac_value"
      },
    })

    bp.plugins:insert({
      name = "mock-downstream",
      route = { id = route.id },
    })

    -- Update mock-downstream to read the hmac
    local handler_path = "apigee-policies-based-plugins/mock-downstream/handler.lua"
    local f = io.open(handler_path, "r")
    local content = f:read("*a")
    f:close()
    content = content .. [[
      local hmac_value = kong.ctx.shared.hmac_value
      if hmac_value then
        kong.response.set_header("X-HMAC", hmac_value)
      end
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
    assert.is_not_nil(r.headers["X-HMAC"])
  end)
end)
