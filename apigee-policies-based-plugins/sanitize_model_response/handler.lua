local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local fun = require "kong.tools.functional"

-- Helper to get a reference to the value at a JSON path
-- Returns: value, parent_table, last_key_in_path, success_boolean
local function get_json_path_ref(data, path_str)
  if not data or not path_str or path_str == "" or path_str == "." then
    return data, nil, nil, true -- If path is empty/root, return the whole data
  end
  local path_parts = {}
  for part in path_str:gmatch("[^.]+") do
    table.insert(path_parts, part)
  end

  local current = data
  local parent = nil
  local last_key = nil

  for i = 1, #path_parts do
    local part = path_parts[i]
    if type(current) == "table" and current[part] ~= nil then
      parent = current
      last_key = part
      current = current[part]
    else
      return nil, nil, nil, false -- Path not found
    end
  end
  return current, parent, last_key, true
end

-- Helper to modify a field at a JSON path
-- Returns: boolean (success)
local function modify_json_field(data, path_str, new_value, action)
  if not data or not path_str then return false end

  if path_str == "." or path_str == "" then
    -- Special case: modify the root element itself.
    -- This function cannot directly modify the 'data' passed to it if it's the root.
    -- The caller needs to handle the root modification.
    if action == "set_root" then return new_value, true end
    return false
  end

  local val, parent, last_key, found = get_json_path_ref(data, path_str)
  if not found or not parent or not last_key then return false end

  if action == "remove" then
    parent[last_key] = nil
  elseif action == "redact" then
    parent[last_key] = new_value
  else
    return false
  end
  return true
end

local SanitizeModelResponseHandler = BasePlugin:extend("sanitize-model-response")

function SanitizeModelResponseHandler:new()
  return SanitizeModelResponseHandler.super.new(self, "sanitize-model-response")
end

function SanitizeModelResponseHandler:body_filter(conf)
  SanitizeModelResponseHandler.super.body_filter(self)

  local original_body = kong.response.get_raw_body()
  if not original_body or original_body == "" then
    kong.log.debug("SanitizeModelResponse: Empty response body. Skipping sanitization.")
    return
  end

  local parsed_body, err = cjson.decode(original_body)
  if not parsed_body then
    kong.log.warn("SanitizeModelResponse: Could not decode response body as JSON. Passing through without deep sanitization. Error: ", err)
    -- We can still apply global string replacements and max_length if not JSON
    local final_response_string = original_body
    for _, replacement_rule in ipairs(conf.replacements) do
      local pattern = replacement_rule.pattern
      local replace_with = replacement_rule.replacement
      local ok, res, gsub_err = ngx.re.gsub(final_response_string, pattern, replace_with, "jo")
      if ok then
        final_response_string = res
      else
        kong.log.warn("SanitizeModelResponse: Failed to apply replacement pattern '", pattern, "' on non-JSON body. Error: ", gsub_err)
      end
    end
    if conf.max_length and #final_response_string > conf.max_length then
      final_response_string = final_response_string:sub(1, conf.max_length)
    end
    kong.response.set_body(final_response_string)
    return
  end

  -- Apply remove_fields
  for _, path in ipairs(conf.remove_fields) do
    if not modify_json_field(parsed_body, path, nil, "remove") then
      kong.log.debug("SanitizeModelResponse: Could not remove field at path: ", path)
    end
  end

  -- Apply redact_fields
  for _, path in ipairs(conf.redact_fields) do
    if not modify_json_field(parsed_body, path, conf.redaction_string, "redact") then
      kong.log.debug("SanitizeModelResponse: Could not redact field at path: ", path)
    end
  end

  -- Get the target part of the response for further string-based sanitization
  local target_value, target_parent, target_key, target_found = get_json_path_ref(parsed_body, conf.response_source_jsonpath)
  local final_response_string = nil

  if target_found then
    if type(target_value) == "table" then
      final_response_string = cjson.encode(target_value)
    else
      final_response_string = tostring(target_value)
    end
  else
    kong.log.warn("SanitizeModelResponse: Target JSON path '", conf.response_source_jsonpath, "' not found. Applying replacements to full body.")
    final_response_string = cjson.encode(parsed_body)
  end

  -- Apply replacements to the target string or full body string
  for _, replacement_rule in ipairs(conf.replacements) do
    local pattern = replacement_rule.pattern
    local replace_with = replacement_rule.replacement
    local ok, res, gsub_err = ngx.re.gsub(final_response_string, pattern, replace_with, "jo")
    if ok then
      final_response_string = res
    else
      kong.log.warn("SanitizeModelResponse: Failed to apply replacement pattern '", pattern, "'. Error: ", gsub_err)
    end
  end

  if conf.max_length and #final_response_string > conf.max_length then
    final_response_string = final_response_string:sub(1, conf.max_length)
    kong.log.debug("SanitizeModelResponse: Response truncated to max_length: ", conf.max_length)
  end

  -- Set new response body
  kong.response.set_header("Content-Type", "application/json") -- Assume JSON output after processing
  kong.response.set_body(final_response_string)

  kong.log.debug("SanitizeModelResponse: Response sanitized and updated.")
end

return SanitizeModelResponseHandler
