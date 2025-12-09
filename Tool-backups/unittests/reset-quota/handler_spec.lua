-- unittests/reset-quota/handler_spec.lua

describe("reset-quota handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should reset a quota", function()
    local handler = require "apigee-policies-based-plugins.reset-quota.handler"
    local conf = {
      quota_name = "my-quota"
    }

    -- This is a simplified test. A real test would require a quota server.
    handler:access(conf)

    -- No assertion, just checking that it doesn't crash
  end)
end)
