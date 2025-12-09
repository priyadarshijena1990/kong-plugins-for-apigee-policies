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

-- Helper to get JSON content string from various sources
local function get_json_content(source_type, source_name)
  if source_type == "request_body" then
    return kong.request.get_raw_body()
  elseif source_type == "shared_context" then
    if source_name then
      local content = kong.ctx.shared[source_name]
      if type(content) == "table" then
        local ok, json_str = pcall(cjson.encode, content)
        if ok then
          return json_str
        else
          kong.log.warn("JSONThreatProtection: Failed to JSON encode shared_context table for key '", source_name, "'.")
          return nil
        end
      else
        return tostring(content) -- Assume it's already a string or convertible
      end
    else
      kong.log.err("JSONThreatProtection: 'source_name' is required when 'source_type' is 'shared_context'.")
      return nil
    end
  end
  return nil
end

local JSONThreatProtectionHandler = BasePlugin:extend("json-threat-protection")

function JSONThreatProtectionHandler:new()
  return JSONThreatProtectionHandler.super.new(self, "json-threat-protection")
end

-- Recursive validation function
-- Returns true if valid, false if violation
local function validate_json(conf, data, current_depth)
  -- Max depth check
  if conf.max_container_depth and conf.max_container_depth > 0 and current_depth > conf.max_container_depth then
    kong.log.warn("JSONThreatProtection: Max container depth (", conf.max_container_depth, ") exceeded at depth ", current_depth, ".")
    return false
  end

  if type(data) == "table" then
    -- Check if it's an array (all keys are sequential numbers)
    local is_array = true
    if #data > 0 then
      for i = 1, #data do
        if data[i] == nil then
          is_array = false
          break
        end
      end
    else -- Empty table could be object or array
      for k, _ in pairs(data) do
        if type(k) ~= "number" then
          is_array = false
          break
        end
      end
    end

    if is_array then
      -- Max array elements check
      if conf.max_array_elements and conf.max_array_elements > 0 and #data > conf.max_array_elements then
        kong.log.warn("JSONThreatProtection: Max array elements (", conf.max_array_elements, ") exceeded (", #data, ").")
        return false
      end
      -- Recursively validate array elements
      for _, value in ipairs(data) do
        if not validate_json(conf, value, current_depth + 1) then
          return false
        end
      end
    else -- It's an object
      -- Max object entry count check
      local entry_count = 0
      for k, _ in pairs(data) do entry_count = entry_count + 1 end
      if conf.max_object_entry_count and conf.max_object_entry_count > 0 and entry_count > conf.max_object_entry_count then
        kong.log.warn("JSONThreatProtection: Max object entry count (", conf.max_object_entry_count, ") exceeded (", entry_count, ").")
        return false
      end
      -- Recursively validate object keys and values
      for key, value in pairs(data) do
        -- Max object entry name length check
        if conf.max_object_entry_name_length and conf.max_object_entry_name_length > 0 and #tostring(key) > conf.max_object_entry_name_length then
          kong.log.warn("JSONThreatProtection: Max object entry name length (", conf.max_object_entry_name_length, ") exceeded (", #tostring(key), ") for key '", tostring(key), "'.")
          return false
        end
        if not validate_json(conf, value, current_depth + 1) then
          return false
        end
      end
    end
  elseif type(data) == "string" then
    -- Max string value length check
    if conf.max_string_value_length and conf.max_string_value_length > 0 and #data > conf.max_string_value_length then
      kong.log.warn("JSONThreatProtection: Max string value length (", conf.max_string_value_length, ") exceeded (", #data, ").")
      return false
    end
  end

  return true -- No violations found at this level
end


function JSONThreatProtectionHandler:access(conf)
  JSONThreatProtectionHandler.super.access(self)

  -- Apigee's policy only runs on JSON content. Enforce this for request body source.
  if conf.source_type == "request_body" then
    local content_type = kong.request.get_header("Content-Type")
    if not content_type or not content_type:find("application/json", 1, true) then
      kong.log.debug("JSONThreatProtection: Content-Type is not application/json, skipping.")
      return
    end
  end

  local json_content_string = get_json_content(conf.source_type, conf.source_name)
  if not json_content_string or json_content_string == "" then
    kong.log.debug("JSONThreatProtection: No JSON content found from source '", conf.source_type, "'. Skipping threat protection.")
    return -- Let request proceed
  end

  local parsed_json, err = cjson.decode(json_content_string)
  if not parsed_json then
    kong.log.warn("JSONThreatProtection: Failed to decode JSON content from source '", conf.source_type, "'. Error: ", err)
    if not conf.on_violation_continue then
      return kong.response.exit(conf.on_violation_status, conf.on_violation_body)
    end
    return
  end

  if not validate_json(conf, parsed_json, 1) then
    kong.log.warn("JSONThreatProtection: JSON content failed validation.")
    if not conf.on_violation_continue then
      return kong.response.exit(conf.on_violation_status, conf.on_violation_body)
    end
    -- If on_violation_continue is true, just return and let request proceed
  else
    kong.log.debug("JSONThreatProtection: JSON content passed validation.")
  end
end

return JSONThreatProtectionHandler
