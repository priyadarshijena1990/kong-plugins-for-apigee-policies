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

-- Helper to get a string value from various sources
local function get_value_from_source(source_type, source_name, phase)
  local value = nil
  if source_type == "header" then
    value = kong.request.get_header(source_name)
  elseif source_type == "query" then
    value = kong.request.get_query_arg(source_name)
  elseif source_type == "body" then
    local raw_body = (phase == "access" and kong.request.get_raw_body()) or (phase == "body_filter" and kong.response.get_raw_body())
    if raw_body then
      local ok, parsed_body = pcall(cjson.decode, raw_body)
      if ok then
        value = get_json_value(parsed_body, source_name)
      else
        kong.log.warn("XMLThreatProtection: Could not decode body as JSON for source '", source_name, "'.")
      end
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  elseif source_type == "literal" then
    value = source_name
  end
  return value and tostring(value) or nil
end

local XMLThreatProtectionHandler = BasePlugin:extend("xml-threat-protection")

function XMLThreatProtectionHandler:new()
  return XMLThreatProtectionHandler.super.new(self, "xml-threat-protection")
end

function XMLThreatProtectionHandler:access(conf)
  XMLThreatProtectionHandler.super.access(self)

  local xml_message_content = get_value_from_source(conf.message_source_type, conf.message_source_name, "access")

  if not xml_message_content or xml_message_content == "" then
    kong.log.debug("XMLThreatProtection: No XML message content found from source '", conf.message_source_type, "'. Skipping threat protection.")
    return true -- Continue processing
  end

  local request_body_for_service = {
    xml_message = xml_message_content,
    max_element_depth = conf.max_element_depth,
    max_element_count = conf.max_element_count,
    max_attribute_count = conf.max_attribute_count,
    max_attribute_name_length = conf.max_attribute_name_length,
    max_attribute_value_length = conf.max_attribute_value_length,
    max_entity_expansion = conf.max_entity_expansion,
  }

  local callout_opts = {
    method = "POST",
    headers = { ["Content-Type"] = "application/json" },
    body = cjson.encode(request_body_for_service),
    timeout = 15000, -- Increased timeout for external validation service
    connect_timeout = 5000,
    ssl_verify = true,
  }

  local res, err = kong.http.client.go(conf.xml_threat_protection_service_url, callout_opts)

  local validation_succeeded = false
  if not res then
    kong.log.err("XMLThreatProtection: Call to XML threat protection service '", conf.xml_threat_protection_service_url, "' failed: ", err)
  elseif res.status ~= 200 then
    kong.log.err("XMLThreatProtection: Threat protection service '", conf.xml_threat_protection_service_url, "' returned error status: ", res.status, " Body: ", res.body)
  else
    local service_response, decode_err = cjson.decode(res.body)
    if not service_response then
      kong.log.err("XMLThreatProtection: Failed to decode JSON response from threat protection service. Error: ", decode_err)
    elseif service_response.valid == true then
      validation_succeeded = true
      kong.log.debug("XMLThreatProtection: XML message passed threat protection.")
    else
      kong.log.warn("XMLThreatProtection: XML threat protection violation detected. Details: ", service_response.details or "No details.")
    end
  end

  if not validation_succeeded then
    if not conf.on_violation_continue then
      return kong.response.exit(conf.on_violation_status, conf.on_violation_body)
    end
    kong.log.warn("XMLThreatProtection: Violation detected but 'on_violation_continue' is true. Continuing processing.")
  end
  return true
end

return XMLThreatProtectionHandler
