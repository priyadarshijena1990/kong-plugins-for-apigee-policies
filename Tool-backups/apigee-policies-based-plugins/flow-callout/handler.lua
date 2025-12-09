local FlowCalloutHandler = {
  PRIORITY = 1000,
}

function FlowCalloutHandler:access(conf)
  local service_object, err = kong.db.services:select_by_name(conf.shared_flow_service_name)
  if not service_object then
    kong.log.err("FlowCallout: Kong Service '", conf.shared_flow_service_name, "' not found. Error: ", tostring(err))
    if not conf.on_flow_error_continue then
      return kong.response.exit(conf.on_flow_error_status, conf.on_flow_error_body)
    end
    return -- Continue if configured
  end

  -- IMPORTANT: This reads the entire request body into memory and consumes it.
  local request_body = kong.request.get_raw_body()

  -- Make internal request to the shared flow service.
  local flow_res, flow_err = kong.service.request.new({
    method = kong.request.get_method(),
    path = kong.request.get_path_with_query(),
    headers = kong.request.get_headers(),
    body = request_body,
    service = service_object,
  }):send()

  local flow_call_succeeded = true
  if not flow_res then
    flow_call_succeeded = false
    kong.log.err("FlowCallout: Internal call to shared flow service '", conf.shared_flow_service_name, "' failed: ", flow_err)
  elseif flow_res.status >= 400 then
    flow_call_succeeded = false
    kong.log.warn("FlowCallout: Shared flow service '", conf.shared_flow_service_name, "' returned error status: ", flow_res.status)
  end

  if conf.store_flow_response_in_shared_context_key then
    local body, body_err = flow_res:read_body()
    if body_err then
      kong.log.err("FlowCallout: Could not read body from shared flow service: ", body_err)
    end
    kong.ctx.shared[conf.store_flow_response_in_shared_context_key] = {
      status = flow_res and flow_res.status or 500,
      headers = flow_res and flow_res.headers or {},
      body = body or flow_err,
    }
    kong.log.debug("FlowCallout: Shared flow response stored in shared context key: ", conf.store_flow_response_in_shared_context_key)
  end

  if not flow_call_succeeded then
    if not conf.on_flow_error_continue then
      kong.log.err("FlowCallout: Aborting request due to failed shared flow execution.")
      return kong.response.exit(conf.on_flow_error_status, conf.on_flow_error_body)
    else
      kong.log.warn("FlowCallout: Shared flow call failed but 'on_flow_error_continue' is true. Continuing request processing.")
    end
  end

  -- CRITICAL FIX: If the original body should be preserved for the final upstream,
  -- it must be set again, as get_raw_body() consumes it.
  if conf.preserve_original_request_body and request_body and request_body ~= "" then
    kong.log.debug("FlowCallout: Preserving original request body for upstream service.")
    kong.request.set_body(request_body)
  end

  kong.log.debug("FlowCallout: Internal call to shared flow service '", conf.shared_flow_service_name, "' completed.")
end

return FlowCalloutHandler
