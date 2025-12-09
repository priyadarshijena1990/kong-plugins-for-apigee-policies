-- unittests/assert-condition/handler_spec.lua

describe("assert-condition handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed()
  end)

  it("should do nothing if condition is true", function()
    local handler = require "apigee-policies-based-plugins.assert-condition.handler"
    local conf = {
      condition = "1 == 1",
      on_false_action = "abort",
      abort_status = 400,
      abort_message = "Condition not met.",
      on_error_continue = false,
    }
    local exited = spy.on(kong.response, "exit")
    handler:access(conf)
    assert.spy(exited).was.not_called()
  end)

  it("should abort if condition is false and action is abort", function()
    local handler = require "apigee-policies-based-plugins.assert-condition.handler"
    local conf = {
      condition = "1 == 2",
      on_false_action = "abort",
      abort_status = 400,
      abort_message = "Condition not met.",
      on_error_continue = false,
    }
    local exited = spy.on(kong.response, "exit")
    handler:access(conf)
    assert.spy(exited).was.called_with(400, { message = "Condition not met." })
  end)

  it("should continue if condition is false and action is continue", function()
    local handler = require "apigee-policies-based-plugins.assert-condition.handler"
    local conf = {
      condition = "1 == 2",
      on_false_action = "continue",
    }
    local exited = spy.on(kong.response, "exit")
    handler:access(conf)
    assert.spy(exited).was.not_called()
  end)

  it("should continue if condition has error and on_error_continue is true", function()
    local handler = require "apigee-policies-based-plugins.assert-condition.handler"
    local conf = {
      condition = "invalid syntax",
      on_error_continue = true,
    }
    local exited = spy.on(kong.response, "exit")
    handler:access(conf)
    assert.spy(exited).was.not_called()
  end)

  it("should abort if condition has error and on_error_continue is false", function()
    local handler = require "apigee-policies-based-plugins.assert-condition.handler"
    local conf = {
      condition = "invalid syntax",
      on_error_continue = false,
    }
    local exited = spy.on(kong.response, "exit")
    handler:access(conf)
    assert.spy(exited).was.called()
  end)
end)
