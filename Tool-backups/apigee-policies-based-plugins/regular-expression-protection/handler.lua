local kong_meta = require "kong.meta"

local RegexProtectionHandler = {}

RegexProtectionHandler.PRIORITY = 2000 -- High priority to run before other plugins
RegexProtectionHandler.VERSION = kong_meta.version

local function get_input_value(conf)
  if conf.input_source == "request_body" then
    return kong.request.get_raw_body()
  elseif conf.input_source == "header" then
    return kong.request.get_header(conf.input_name)
  elseif conf.input_source == "query" then
    return (kong.request.get_query())[conf.input_name]
  elseif conf.input_source == "uri_path" then
    return kong.request.get_path()
  end
  return nil
end

local function handle_block(conf)
  return kong.response.exit(conf.block_status, { message = conf.block_message })
end

function RegexProtectionHandler:access(conf)
  local input_value, err = get_input_value(conf)

  if err then
    kong.log.err("Regex Protection: Failed to get input value: ", err)
    -- Decide if an error getting the input should block. For safety, we assume not.
    return
  end

  if not input_value or input_value == "" then
    -- No input to check, so we can proceed.
    return
  end

  -- Check against deny patterns
  if conf.deny_patterns then
    for _, pattern in ipairs(conf.deny_patterns) do
      local match, _, err = ngx.re.find(input_value, pattern, "jo")
      if err then
        kong.log.err("Regex Protection: Invalid deny pattern '", pattern, "': ", err)
        -- Faulty pattern should not block requests, but should be logged.
        goto continue_deny_loop
      end
      if match then
        kong.log.warn("Regex Protection: Deny pattern '", pattern, "' matched input. Blocking request.")
        return handle_block(conf)
      end
      ::continue_deny_loop::
    end
  end

  -- Check against allow patterns (if any deny patterns passed)
  if conf.allow_patterns and #conf.allow_patterns > 0 then
    local is_allowed = false
    for _, pattern in ipairs(conf.allow_patterns) do
      local match, _, err = ngx.re.find(input_value, pattern, "jo")
      if err then
        kong.log.err("Regex Protection: Invalid allow pattern '", pattern, "': ", err)
        goto continue_allow_loop
      end
      if match then
        is_allowed = true
        break -- One match is enough to allow
      end
      ::continue_allow_loop::
    end

    if not is_allowed then
      kong.log.warn("Regex Protection: Input did not match any allow patterns. Blocking request.")
      return handle_block(conf)
    end
  end
end

return RegexProtectionHandler