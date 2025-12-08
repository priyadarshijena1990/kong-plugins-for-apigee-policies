-- unittests/publish-message/handler_spec.lua

describe("publish-message handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should publish a message", function()
    local handler = require "apigee-policies-based-plugins.publish-message.handler"
    local conf = {
      topic = "my-topic",
      message_source = "literal",
      message = "my-message"
    }

    -- This is a simplified test. A real test would require a message broker.
    handler:access(conf)

    -- No assertion, just checking that it doesn't crash
  end)
end)
