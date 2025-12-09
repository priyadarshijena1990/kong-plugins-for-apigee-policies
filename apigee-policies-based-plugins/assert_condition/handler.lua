local kong = require "kong"
local cjson = require "cjson"

local AssertConditionHandler = {}

AssertConditionHandler.PRIORITY = 100
AssertConditionHandler.VERSION = kong.version

local function handle_error(conf, message)
  kong.log.err(message)
  if not conf.on_error_continue then
    return kong.response.exit(500, { message = "Error evaluating condition: " .. message })
  end
end

local function handle_abort(conf)
  return kong.response.exit(conf.abort_status, { message = conf.abort_message })
end

function AssertConditionHandler:access(conf)
  local ok, result = kong.run_in_sandbox(conf.condition, { kong = kong })

  if not ok then
    return handle_error(conf, "Error during condition evaluation: " .. result)
  end

  if not result then -- Condition evaluated to false or nil
    kong.log.debug("Assert Condition: Condition evaluated to false. Action: ", conf.on_false_action)
    if conf.on_false_action == "abort" then
      return handle_abort(conf)
    end
    -- If on_false_action is "continue", do nothing and let the request proceed.
  else
    kong.log.debug("Assert Condition: Condition evaluated to true. Request proceeds.")
  end
end

-- This plugin typically runs early in the request flow to assert conditions.
-- No other phases are generally needed for this functionality.

return AssertConditionHandler