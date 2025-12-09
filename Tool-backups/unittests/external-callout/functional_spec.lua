-- unittests/external-callout/functional_spec.lua

describe("external-callout functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should make an external callout and store the response", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("external-callout")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    -- Mock external service
    local external_service = bp.services:insert({
      url = "http://localhost:12345"
    })
    local external_route = bp.routes:insert({
      hosts = { "external-service" },
      paths = { "/" },
      service = external_service
    })
    bp.plugins:insert({
      name = "request-transformer",
      route = { id = external_route.id },
      config = {
        replace = {
          body = "external response"
        }
      }
    })

    bp.plugins:insert({
      name = "external-callout",
      route = { id = route.id },
      config = {
        callout_url = "http://external-service/",
        response_to_shared_context_key = "callout_response"
      },
    })

    bp.plugins:insert({
      name = "mock-downstream",
      route = { id = route.id },
    })
    
    -- Update mock-downstream to read the callout response
    local handler_path = "apigee-policies-based-plugins/mock-downstream/handler.lua"
    local f = io.open(handler_path, "r")
    local content = f:read("*a")
    f:close()
    content = content .. [[
      local callout_response = kong.ctx.shared.callout_response
      if callout_response then
        kong.response.set_header("X-Callout-Status", callout_response.status)
        kong.response.set_header("X-Callout-Body", callout_response.body)
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
    assert.equal("200", r.headers["X-Callout-Status"])
    assert.equal("external response", r.headers["X-Callout-Body"])
  end)
end)
