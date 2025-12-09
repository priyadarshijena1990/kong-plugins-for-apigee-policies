local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson" -- Kong usually has cjson available
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

local SetDialogflowResponseHandler = BasePlugin:extend("set-dialogflow-response")

function SetDialogflowResponseHandler:new()
  return SetDialogflowResponseHandler.super.new(self, "set-dialogflow-response")
end

function SetDialogflowResponseHandler:body_filter(conf)
  SetDialogflowResponseHandler.super.body_filter(self)

  local dialogflow_response_raw = nil
  local parsed_dialogflow_response = nil

  -- Get raw Dialogflow response based on configuration
  if conf.response_source == "upstream_body" then
    dialogflow_response_raw = kong.response.get_raw_body()
  elseif conf.response_source == "shared_context" then
    if conf.shared_context_key then
      dialogflow_response_raw = kong.ctx.shared[conf.shared_context_key]
      if type(dialogflow_response_raw) == "table" then
        -- If it's already a table, no need to decode
        parsed_dialogflow_response = dialogflow_response_raw
      end
    else
      kong.log.err("SetDialogflowResponse plugin: 'shared_context_key' is required when 'response_source' is 'shared_context'.")
      return
    end
  end

  -- Attempt to parse raw response if it's a string
  if dialogflow_response_raw and type(dialogflow_response_raw) == "string" then
    local ok, decoded = pcall(cjson.decode, dialogflow_response_raw)
    if ok then
      parsed_dialogflow_response = decoded
    else
      kong.log.warn("SetDialogflowResponse plugin: Failed to decode Dialogflow response as JSON. Error: ", decoded)
    end
  end

  local final_client_response = {}
  local use_default_response = true

  if parsed_dialogflow_response then
    for _, mapping in ipairs(conf.mappings) do
      local value = resolve_jsonpath(parsed_dialogflow_response, mapping.dialogflow_jsonpath)
      if value ~= nil then
        final_client_response[mapping.output_field] = value
        use_default_response = false
      end
    end
  end

  local response_body_to_send = nil
  if not use_default_response then
    response_body_to_send = cjson.encode(final_client_response)
  elseif conf.default_response_body then
    -- Use default response body if specified and no valid data extracted
    response_body_to_send = conf.default_response_body
  else
    -- Fallback to an empty JSON object if no data extracted and no default provided
    response_body_to_send = "{}"
  end

  -- Set new response body and Content-Type
  kong.response.set_header("Content-Type", conf.output_content_type)
  kong.response.set_body(response_body_to_send)

  kong.log.debug("SetDialogflowResponse plugin: Final client response: ", response_body_to_send)
end

return SetDialogflowResponseHandler
