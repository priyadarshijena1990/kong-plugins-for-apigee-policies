local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local fun = require "kong.tools.functional"

-- Helper to safely get value from JSON body using simple dot notation
local function get_json_value(json_table, path)
  if not json_table or not path or path == "" then
    return json_table -- Return whole table if path is empty/root
  end
  local parts = {}
  for part in path:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  local current = json_table
  for _, part in ipairs(parts) do
    if type(current) == "table" and current[part] ~= nil then
      current = current[part]
    else
      return nil -- Path not found
    end
  end
  return current
end

-- Helper to get value for a trace point based on source_type and phase
local function get_value_for_trace_point(source_type, source_name, phase)
  local value = nil
  if source_type == "header" then
    value = kong.request.get_header(source_name)
  elseif source_type == "query" then
    value = kong.request.get_query_arg(source_name)
  elseif source_type == "path" then
    value = kong.request.get_uri()
  elseif source_type == "body" then
    local raw_body = kong.request.get_raw_body()
    if raw_body then
      if source_name and source_name ~= "" and source_name ~= "." then
        local ok, parsed_body = pcall(cjson.decode, raw_body)
        if ok then value = get_json_value(parsed_body, source_name) end
      else
        value = raw_body
      end
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  elseif source_type == "literal" then
    value = source_name
  elseif source_type == "response_header" then
    if phase == "body_filter" or phase == "log" then value = kong.response.get_header(source_name) end
  elseif source_type == "response_body" then
    if phase == "body_filter" or phase == "log" then
      local raw_body = kong.response.get_raw_body()
      if raw_body then
        if source_name and source_name ~= "" and source_name ~= "." then
          local ok, parsed_body = pcall(cjson.decode, raw_body)
          if ok then value = get_json_value(parsed_body, source_name) end
        else
          value = raw_body
        end
      end
    end
  elseif source_type == "status" then
    if phase == "body_filter" or phase == "log" then value = kong.response.get_status() end
  elseif source_type == "latency" then
    if phase == "body_filter" or phase == "log" then value = kong.service.request_latency() end
  end
  return value
end

-- Capture and store data for shared context
local function capture_and_store_data(conf, phase)
  local captured_data = {}
  for _, trace_point in ipairs(conf.trace_points) do
    local value, err = pcall(get_value_for_trace_point, trace_point.source_type, trace_point.source_name, phase)
    if err then
      kong.log.err("TraceCapture: Error capturing trace point '", trace_point.name, "' in phase '", phase, "'. Error: ", err)
      if not conf.on_error_continue and phase == "access" then -- Only terminate in access phase
        return false, kong.response.exit(500, "TraceCapture: Internal error during data capture.")
      end
      value = nil -- Do not store erroneous value
    end

    if value ~= nil then
      captured_data[trace_point.name] = value
    end
  end

  if conf.store_in_shared_context_prefix then
    local prefix = conf.store_in_shared_context_prefix
    if prefix:sub(-1) ~= "." then prefix = prefix .. "." end
    for name, value in pairs(captured_data) do
      kong.ctx.shared[prefix .. name] = value
    end
  end
  
  -- Store for external logger in log phase
  kong.ctx.shared.trace_capture_data_for_logger = kong.ctx.shared.trace_capture_data_for_logger or {}
  for name, value in pairs(captured_data) do
    kong.ctx.shared.trace_capture_data_for_logger[name] = value
  end

  return true
end

local TraceCaptureHandler = BasePlugin:extend("trace-capture")

function TraceCaptureHandler:new()
  return TraceCaptureHandler.super.new(self, "trace-capture")
end

function TraceCaptureHandler:access(conf)
  TraceCaptureHandler.super.access(self)
  return capture_and_store_data(conf, "access")
end

function TraceCaptureHandler:body_filter(conf)
  TraceCaptureHandler.super.body_filter(self)
  return capture_and_store_data(conf, "body_filter")
end

function TraceCaptureHandler:log(conf)
  TraceCaptureHandler.super.log(self)

  -- Collect any remaining data (e.g., status, latency) and send to external logger
  capture_and_store_data(conf, "log")

  if conf.external_logger_url and kong.ctx.shared.trace_capture_data_for_logger then
    local callout_opts = {
      method = conf.method,
      headers = conf.headers,
      body = cjson.encode(kong.ctx.shared.trace_capture_data_for_logger),
      timeout = conf.timeout,
      connect_timeout = 5000, -- Default
      ssl_verify = true,      -- Default
    }

    local res, err = kong.http.client.go(conf.external_logger_url, callout_opts)

    if not res then
      kong.log.err("TraceCapture: Failed to send trace data to '", conf.external_logger_url, "'. Error: ", err)
    elseif res.status >= 400 then
      kong.log.warn("TraceCapture: Logger service '", conf.external_logger_url, "' returned error status: ", res.status, " Body: ", res.body)
    else
      kong.log.debug("TraceCapture: Successfully sent trace data to '", conf.external_logger_url, "'.")
    end
  end
end

return TraceCaptureHandler
