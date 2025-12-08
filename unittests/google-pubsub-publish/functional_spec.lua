-- unittests/google-pubsub-publish/functional_spec.lua

describe("google-pubsub-publish functional", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should publish a message to pubsub", function()
    local pongo = require "pongo"
    local bp = pongo.get_plugin_by_name("google-pubsub-publish")

    local route = bp.routes:insert({
      hosts = { "example.com" },
      paths = { "/" },
      service = bp.services:insert({
        url = "http://httpbin.org/get",
      }),
    })

    -- Mock Google Pub/Sub service
    local pubsub_service = bp.services:insert({
      url = "http://localhost:12345"
    })
    local pubsub_route = bp.routes:insert({
      hosts = { "pubsub-service" },
      paths = { "/" },
      service = pubsub_service
    })
    bp.plugins:insert({
      name = "request-transformer",
      route = { id = pubsub_route.id },
      config = {
        replace = {
          body = "{}"
        }
      }
    })

    bp.plugins:insert({
      name = "google-pubsub-publish",
      route = { id = route.id },
      config = {
        project_id = "my-project",
        topic = "my-topic",
        message_source_type = "literal",
        message_source_name = "my-message",
        _service_url = "http://pubsub-service/"
      },
    })

    local r = bp.proxy:send {
      method = "GET",
      host = "example.com",
      path = "/",
    }

    assert.equal(200, r.status)
  end)
end)
