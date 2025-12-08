-- unittests/google-pubsub-publish/handler_spec.lua

describe("google-pubsub-publish handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should publish a message to pubsub", function()
    local handler = require "apigee-policies-based-plugins.google-pubsub-publish.handler"
    local conf = {
      project_id = "my-project",
      topic = "my-topic",
      message_source_type = "literal",
      message_source_name = "my-message"
    }

    local request_spy = spy.on(kong.http.client, "request", function()
      return { status = 200, body = "{}" }
    end)
    
    handler:access(conf)

    assert.spy(request_spy).was.called()
  end)
end)
