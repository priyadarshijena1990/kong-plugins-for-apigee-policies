-- unittests/statistics-collector/handler_spec.lua

describe("statistics-collector handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should collect statistics", function()
    local handler = require "apigee-policies-based-plugins.statistics-collector.handler"
    local conf = {
      metrics = {
        {
          name = "my-metric",
          value_source = "literal",
          value = 1
        }
      }
    }
    
    handler:log(conf)

    -- No assertion, just checking that it doesn't crash
  end)
end)
