local cjson = require "cjson"

local ExternalCalloutHandler = {
  PRIORITY = 1000
}

function ExternalCalloutHandler:access(conf)
  local request_body_for_external_service = nil

  if conf.request_body_source_type == "request_body" then
    request_body_for_external_service = kong.request.get_raw_body()
  elseif conf.request_body_source_type == "shared_context" then
    if conf.request_body_source_name then
      local val = kong.ctx.shared[conf.request_body_source_name]
      if val then
        if type(val) == "table" then
          local ok, json_str = pcall(cjson.encode, val)
          if ok then
            request_body_for_external_service = json_str
          else
            kong.log.warn("ExternalCallout: Failed to JSON encode shared_context value for key '", conf.request_body_source_name, "'. Sending as string.")
            request_body_for_external_service = tostring(val)
          end
        else
          request_body_for_external_service = tostring(val)
        end
      end
    else
      kong.log.err("ExternalCallout: 'request_body_source_name' is required when 'request_body_source_type' is 'shared_context'.")
      if not conf.on_error_continue and conf.wait_for_response then
        return kong.response.exit(conf.on_error_status, conf.on_error_body)
      end
      return -- Continue if configured or fire-and-forget
    end
  end

  local res, err = kong.http.client.request({
    method = conf.method,
    url = conf.callout_url,
    headers = conf.headers,
    body = request_body_for_external_service,
    timeout = 10000,          -- Default timeout for callout
    connect_timeout = 5000,
    ssl_verify = true,        -- Default to SSL verification
    follow_redirects = false, -- Default to not follow redirects
  })

  if conf.wait_for_response then
    local body, body_err
    if res then
      body, body_err = res:read_body()
      if body_err then
        kong.log.err("ExternalCallout: External service '", conf.callout_url, "' failed to read body: ", body_err)
      end
    end

    local callout_succeeded = true
    if not res then
      callout_succeeded = false
      kong.log.err("ExternalCallout: Call to external service '", conf.callout_url, "' failed: ", err)
    elseif res.status >= 400 then
      callout_succeeded = false
      kong.log.warn("ExternalCallout: External service '", conf.callout_url, "' returned error status: ", res.status, " Body: ", body)
    end

    if conf.response_to_shared_context_key then
      kong.ctx.shared[conf.response_to_shared_context_key] = {
        status = res and res.status or 0,
        headers = res and res.headers or {},
        body = body or err, -- Store error message in body if call failed
      }
      kong.log.debug("ExternalCallout: External service response stored in shared context key: ", conf.response_to_shared_context_key)
    end

    if not callout_succeeded and not conf.on_error_continue then
      kong.log.err("ExternalCallout: Aborting request due to failed external callout.")
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    elseif not callout_succeeded and conf.on_error_continue then
      kong.log.warn("ExternalCallout: External callout failed but 'on_error_continue' is true. Continuing request processing.")
    end
    kong.log.debug("ExternalCallout: Call to external service '", conf.callout_url, "' completed.")
  else -- Fire and forget
    kong.log.debug("ExternalCallout: Fire-and-forget call to '", conf.callout_url, "' initiated. Not waiting for response.")
  end
end

return ExternalCalloutHandler
