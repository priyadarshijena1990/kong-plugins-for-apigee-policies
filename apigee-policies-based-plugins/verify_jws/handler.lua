local http = require "resty.http"
local cjson = require "cjson"

local ServiceCalloutHandler = {}

ServiceCalloutHandler.PRIORITY = 800 -- Runs after most auth/setup plugins
ServiceCalloutHandler.VERSION = "1.0.0"

function ServiceCalloutHandler:new()
  return {}
end

local function handle_error(conf, status, message)
  kong.log.err("service-callout: ", message)
  if not conf.on_error_continue then
    return kong.response.exit(status, { message = message })
  end
end

-- Main handler function
function ServiceCalloutHandler:access(conf)
  local httpc = http.new()
  httpc:set_timeout(conf.timeout)

  local options = {
    method = conf.method,
    headers = conf.headers,
    ssl_verify = conf.ssl_verify,
  }

  -- Add body if it's a method that supports it
  if conf.method == "POST" or conf.method == "PUT" or conf.method == "PATCH" then
    options.body = conf.body
  end

  -- Build the URI with query parameters
  local uri = conf.url
  if conf.query_params then
    local query_string = httpc:encode_queries(conf.query_params)
    if query_string and query_string ~= "" then
      uri = uri .. "?" .. query_string
    end
  end

  -- Fire and Forget mode
  if conf.fire_and_forget then
    local ok, err = ngx.timer.at(0, function()
      local _, timer_err = httpc:request_uri(uri, options)
      if timer_err then
        kong.log.err("service-callout (fire-and-forget): Failed to execute callout: ", timer_err)
      end
    end)
    if not ok then
      kong.log.err("service-callout: Could not create timer for fire-and-forget callout: ", err)
    end
    return -- Continue immediately
  end

  -- Synchronous mode
  local res, err = httpc:request_uri(uri, options)

  if not res then
    return handle_error(conf, 503, "Service callout failed: " .. (err or "unknown error"))
  end

  -- Store the response in shared context
  if conf.output_variable_name then
    local response_body = res:read_body()
    kong.ctx.shared[conf.output_variable_name] = {
      status = res.status,
      headers = res.headers,
      body = response_body,
    }
    kong.log.debug("service-callout: Stored callout response in kong.ctx.shared.", conf.output_variable_name)
  end
end

return ServiceCalloutHandler