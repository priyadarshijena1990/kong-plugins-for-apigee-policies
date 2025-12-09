local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"

local LogSharedContextHandler = BasePlugin:extend("log-shared-context")
LogSharedContextHandler.PRIORITY = 0 -- Run as late as possible in the log phase

function LogSharedContextHandler:new()
  LogSharedContextHandler.super.new(self)
end

function LogSharedContextHandler:log(conf)
  LogSharedContextHandler.super.log(conf)
  
  local data_to_log = {}
  local prefix = conf.target_key_prefix
  
  -- Collect data from shared context
  if prefix and prefix ~= "" then
    for k, v in pairs(kong.ctx.shared) do
      if k == prefix or k:sub(1, #prefix) == prefix then
        data_to_log[k] = v
      end
    end
  else
    -- if no prefix, log everything in shared context
    for k, v in pairs(kong.ctx.shared) do
      data_to_log[k] = v
    end
  end

  local log_payload = {
    log_key = conf.log_key,
    timestamp = ngx.now(),
    data = data_to_log
  }
  
  local log_string, err = cjson.encode(log_payload)
  if err then
    kong.log.err("LogSharedContext: Failed to encode log payload: ", err)
    return
  end

  -- If an HTTP endpoint is configured, send the log asynchronously
  if conf.http_endpoint and conf.http_endpoint ~= "" then
    local callout_opts = {
      method = conf.http_method,
      headers = conf.http_headers or {},
      body = log_string,
      timeout = 5000, -- 5 second timeout for the log call
    }
    -- Ensure Content-Type is set for JSON
    callout_opts.headers["Content-Type"] = "application/json"

    -- Use a timer to make the call non-blocking
    local ok, timer_err = kong.timer.at(0, function(_, opts, endpoint)
      local _, http_err = kong.http.client.go(endpoint, opts)
      if http_err then
        kong.log.err("LogSharedContext: Async HTTP log call failed: ", http_err)
      end
    end, callout_opts, conf.http_endpoint)

    if not ok then
      kong.log.err("LogSharedContext: Failed to create async timer for logging: ", timer_err)
    end
  else
    -- Fallback to logging to Kong's standard log file
    kong.log.notice(log_string)
  end
end

return LogSharedContextHandler
