-- unittests/get-oauth-v2-info/functional_spec.lua

describe("get-oauth-v2-info functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should get oauth2 info and store it in ctx.shared", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("get-oauth-v2-info")

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
      name = "get-oauth-v2-info",
      route = { id = route.id },
      config = {
        token_source_type = "header",
        token_source_name = "x-token",
        output_context_variable = "oauth2_info"
      },
    })

    bp.plugins:insert({
      name = "mock-downstream",
      route = { id = route.id },
    })
    
    -- Update mock-downstream to read the oauth2 info
    local handler_path = "apigee-policies-based-plugins/mock-downstream/handler.lua"
    local f = io.open(handler_path, "r")
    local content = f:read("*a")
    f:close()
    content = content .. [[
      local oauth2_info = kong.ctx.shared.oauth2_info
      if oauth2_info then
        kong.response.set_header("X-Oauth2-Token-Id", oauth2_info.id)
      end
    ]]
    f = io.open(handler_path, "w")
    f:write(content)
    f:close()

    local r = bp.proxy:send {
      method = "GET",
      host = "example.com",
      path = "/",
      headers = {
        ["x-token"] = token
      }
    }

    assert.equal(200, r.status)
    assert.is_not_nil(r.headers["X-Oauth2-Token-Id"])
  end)
end)
