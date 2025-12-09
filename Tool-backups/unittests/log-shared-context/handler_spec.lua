-- unittests/log-shared-context/handler_spec.lua

describe("log-shared-context handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {
          my_var = "my-value"
        }
      }
    })
  end)

  it("should log the shared context", function()
    local handler = require "apigee-policies-based-plugins.log-shared-context.handler"
    local conf = {
      log_level = "info"
    }

    local log = spy.on(kong.log, "info")
    
    handler:access(conf)

    assert.spy(log).was.called()
  end)
end)
