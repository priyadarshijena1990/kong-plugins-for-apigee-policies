-- unittests/flow-callout/functional_spec.lua

describe("flow-callout functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should make a flow callout and store the response", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("flow-callout")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    -- Mock flow service
    local flow_service = bp.services:insert({
      url = "http://localhost:12345"
    })
    local flow_route = bp.routes:insert({
      hosts = { "flow-service" },
      paths = { "/" },
      service = flow_service
    })
    bp.plugins:insert({
      name = "request-transformer",
      route = { id = flow_route.id },
      config = {
        replace = {
          body = "flow response"
        }
      }
    })

    bp.plugins:insert({
      name = "flow-callout",
      route = { id = route.id },
      config = {
        shared_flow_service_name = flow_service.name,
        store_flow_response_in_shared_context_key = "flow_response"
      },
    })

    bp.plugins:insert({
      name = "mock-downstream",
      route = { id = route.id },
    })

    -- Update mock-downstream to read the flow response
    local handler_path = "apigee-policies-based-plugins/mock-downstream/handler.lua"
    local f = io.open(handler_path, "r")
    local content = f:read("*a")
    f:close()
    content = content .. [[
      local flow_response = kong.ctx.shared.flow_response
      if flow_response then
        kong.response.set_header("X-Flow-Status", flow_response.status)
        kong.response.set_header("X-Flow-Body", flow_response.body)
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
    assert.equal("200", r.headers["X-Flow-Status"])
    assert.equal("flow response", r.headers["X-Flow-Body"])
  end)
end)
