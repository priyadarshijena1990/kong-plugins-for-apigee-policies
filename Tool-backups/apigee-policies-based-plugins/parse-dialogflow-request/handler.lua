local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local fun = require "kong.tools.functional"

-- Simple JSONPath resolver (dot notation only)
local function resolve_jsonpath(data, jsonpath)
  if not data or not jsonpath or jsonpath == "" then
    return data
  end
  local path_parts = {}
  for part in jsonpath:gmatch("[^.]+") do
    table.insert(path_parts, part)
  end

  local current_data = data
  for _, part in ipairs(path_parts) do
    if type(current_data) == "table" and current_data[part] ~= nil then
      current_data = current_data[part]
    else
      return nil -- Path not found
    end
  end
  return current_data
end

local ParseDialogflowRequestHandler = BasePlugin:extend("parse-dialogflow-request")

function ParseDialogflowRequestHandler:new()
  return ParseDialogflowRequestHandler.super.new(self, "parse-dialogflow-request")
end

function ParseDialogflowRequestHandler:access(conf)
  ParseDialogflowRequestHandler.super.access(self)

  local raw_dialogflow_request = nil

  -- Get raw Dialogflow request based on configuration
  if conf.source_type == "request_body" then
    raw_dialogflow_request = kong.request.get_raw_body()
  elseif conf.source_type == "shared_context" then
    if conf.source_key then
      raw_dialogflow_request = kong.ctx.shared[conf.source_key]
      if type(raw_dialogflow_request) == "table" then
        -- If it's already a table, we can proceed with it directly
        -- but if it's a JSON string it needs decoding.
        -- For consistency, let's assume raw_dialogflow_request holds a JSON string
        -- and will be decoded below. If it's a table, we'll encode it then decode.
        local ok, encoded = pcall(cjson.encode, raw_dialogflow_request)
        if ok then
          raw_dialogflow_request = encoded
        else
          kong.log.err("ParseDialogflowRequest: Could not encode shared context table to JSON string for parsing.")
          raw_dialogflow_request = nil
        end
      end
    else
      kong.log.err("ParseDialogflowRequest: 'source_key' is required when 'source_type' is 'shared_context'.")
      if not conf.on_parse_error_continue then
        return kong.response.exit(conf.on_parse_error_status, conf.on_parse_error_body)
      end
      return
    end
  end

  if not raw_dialogflow_request or raw_dialogflow_request == "" then
    kong.log.debug("ParseDialogflowRequest: No raw Dialogflow request found. Skipping parsing.")
    return
  end

  local parsed_dialogflow_request, err = cjson.decode(raw_dialogflow_request)
  if not parsed_dialogflow_request then
    kong.log.err("ParseDialogflowRequest: Failed to decode Dialogflow request as JSON. Error: ", err)
    if not conf.on_parse_error_continue then
      return kong.response.exit(conf.on_parse_error_status, conf.on_parse_error_body)
    end
    return
  end

  -- Apply mappings
  for _, mapping in ipairs(conf.mappings) do
    local extracted_value = resolve_jsonpath(parsed_dialogflow_request, mapping.dialogflow_jsonpath)
    if extracted_value ~= nil then
      kong.ctx.shared[mapping.output_key] = extracted_value
      kong.log.debug("ParseDialogflowRequest: Extracted '", mapping.dialogflow_jsonpath, "' and stored in '", mapping.output_key, "': ", tostring(extracted_value))
    else
      kong.log.debug("ParseDialogflowRequest: JSONPath '", mapping.dialogflow_jsonpath, "' not found. Skipping storage for '", mapping.output_key, "'.")
    end
  end

  kong.log.debug("ParseDialogflowRequest: Dialogflow request parsed and mapped to shared context.")
end

return ParseDialogflowRequestHandler
