local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"

local ServiceCalloutHandler = BasePlugin:extend("service-callout")
ServiceCalloutHandler.PRIORITY = 1000

function ServiceCalloutHandler:new()
  ServiceCalloutHandler.super.new(self)
end

local function do_callout(conf)
  local request_body_for_callout = nil

  if conf.request_body_source_type == "request_body" then
    request_body_for_callout = kong.request.get_raw_body()
  elseif conf.request_body_source_type == "shared_context" then
    if conf.request_body_source_name then
      local val = kong.ctx.shared[conf.request_body_source_name]
      if val then
        if type(val) == "table" then
          local ok, json_str = pcall(cjson.encode, val)
          if ok then
            request_body_for_callout = json_str
          else
            kong.log.warn("ServiceCallout: Failed to JSON encode shared_context value for key '", conf.request_body_source_name, "'. Sending as string.")
            request_body_for_callout = tostring(val)
          end
        else
          request_body_for_callout = tostring(val)
        end
      end
    else
      kong.log.err("ServiceCallout: 'request_body_source_name' is required when 'request_body_source_type' is 'shared_context'.")
      if not conf.on_error_continue and conf.wait_for_response then
        return kong.response.exit(conf.on_error_status, conf.on_error_body)
      end
      return
    end
  end

  local callout_opts = {
    method = conf.method,
    headers = conf.headers,
    body = request_body_for_callout,
    timeout = 10000,
    connect_timeout = 5000,
    ssl_verify = true,
    follow_redirects = false,
  }

  if conf.wait_for_response then
    -- Synchronous call
    local res, err = kong.http.client.go(conf.callout_url, callout_opts)
    local callout_succeeded = true
    if not res then
      callout_succeeded = false
      kong.log.err("ServiceCallout: Call to external service '", conf.callout_url, "' failed: ", err)
    elseif res.status >= 400 then
      callout_succeeded = false
      kong.log.warn("ServiceCallout: External service '", conf.callout_url, "' returned error status: ", res.status)
    end

    if conf.response_to_shared_context_key then
      local response_body = res and res.body or nil
      if response_body then
          local json_body, json_err = cjson.decode(response_body)
          if json_err then
             -- if not json, store as raw string
             kong.ctx.shared[conf.response_to_shared_context_key] = {
                status = res and res.status or 0,
                headers = res and res.headers or {},
                body = response_body,
             }
          else
             kong.ctx.shared[conf.response_to_shared_context_key] = {
                status = res and res.status or 0,
                headers = res and res.headers or {},
                body = json_body,
             }
          end
      else
        kong.ctx.shared[conf.response_to_shared_context_key] = {
            status = res and res.status or 0,
            headers = res and res.headers or {},
            body = err, -- Store error message in body if call failed
        }
      end
      kong.log.debug("ServiceCallout: External service response stored in shared context key: ", conf.response_to_shared_context_key)
    end

    if not callout_succeeded and not conf.on_error_continue then
      kong.log.err("ServiceCallout: Aborting request due to failed external callout.")
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
  else
    -- Asynchronous (fire and forget) call
    kong.log.debug("ServiceCallout: Initiating fire-and-forget call to '", conf.callout_url, "'.")
    local ok, err = kong.timer.at(0, function(_, url, opts)
      local _, call_err = kong.http.client.go(url, opts)
      if call_err then
        kong.log.err("ServiceCallout (async): Call to '", url, "' failed: ", call_err)
      end
    end, conf.callout_url, callout_opts)

    if not ok then
      kong.log.err("ServiceCallout: Failed to create async timer for callout: ", err)
    end
  end
end

function ServiceCalloutHandler:access(conf)
  ServiceCalloutHandler.super.access(self)
  do_callout(conf)
end

return ServiceCalloutHandler