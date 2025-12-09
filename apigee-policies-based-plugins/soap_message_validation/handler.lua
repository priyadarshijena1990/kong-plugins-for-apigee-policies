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
        kong.log.warn("SOAPMessageValidation: Could not decode body as JSON for source '", source_name, "'.")
      end
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  elseif source_type == "literal" then
    value = source_name
  end
  return value and tostring(value) or nil
end

local SOAPMessageValidationHandler = BasePlugin:extend("soap-message-validation")

function SOAPMessageValidationHandler:new()
  return SOAPMessageValidationHandler.super.new(self, "soap-message-validation")
end

-- Helper to get SOAP message content based on phase
local function get_message_content(conf, phase)
  if conf.message_source_type == "request_body" then
    if phase == "access" then return kong.request.get_raw_body() end
  elseif conf.message_source_type == "response_body" then
    if phase == "body_filter" then return kong.response.get_raw_body() end
  elseif conf.message_source_type == "shared_context" and conf.message_source_name then
    -- shared_context can be accessed in either phase
    return get_value_from_source("shared_context", conf.message_source_name, phase)
  end
  return nil
end

-- Helper to get XSD content
local function get_xsd_content(conf)
  if conf.xsd_source_type == "literal" then
    return conf.xsd_literal
  elseif conf.xsd_source_type == "url" then
    -- For simplicity, external service will fetch URL. Pass URL.
    return conf.xsd_source_name
  elseif conf.xsd_source_type == "shared_context" then
    return get_value_from_source("shared_context", conf.xsd_source_name)
  end
  return nil
end

-- Main validation logic
local function perform_validation(self, conf, phase)
  local soap_message_content = get_message_content(conf, phase)
  if not soap_message_content or soap_message_content == "" then
    kong.log.debug("SOAPMessageValidation: No SOAP message content found for validation in phase '", phase, "'. Skipping.")
    return true -- Continue processing
  end

  local xsd_schema_content = get_xsd_content(conf)
  if not xsd_schema_content or xsd_schema_content == "" then
    kong.log.err("SOAPMessageValidation: No XSD schema content found. Cannot validate SOAP message.")
    if not conf.on_validation_failure_continue then
      return kong.response.exit(conf.on_validation_failure_status, conf.on_validation_failure_body)
    end
    return true
  end

  local request_body_for_service = cjson.encode({
    soap_message = soap_message_content,
    xsd_schema = xsd_schema_content,
    xsd_source_type = conf.xsd_source_type, -- Pass type to service if it needs to fetch URL
    validate_parts = conf.validate_parts,
  })

  local callout_opts = {
    method = "POST",
    headers = { ["Content-Type"] = "application/json" },
    body = request_body_for_service,
    timeout = 15000, -- Increased timeout for external validation service
    connect_timeout = 5000,
    ssl_verify = true,
  }

  local res, err = kong.http.client.go(conf.soap_validation_service_url, callout_opts)

  local validation_succeeded = false
  if not res then
    kong.log.err("SOAPMessageValidation: Call to validation service '", conf.soap_validation_service_url, "' failed: ", err)
  elseif res.status ~= 200 then
    kong.log.err("SOAPMessageValidation: Validation service '", conf.soap_validation_service_url, "' returned error status: ", res.status, " Body: ", res.body)
  else
    local service_response, decode_err = cjson.decode(res.body)
    if not service_response then
      kong.log.err("SOAPMessageValidation: Failed to decode JSON response from validation service. Error: ", decode_err)
    elseif service_response.valid == true then
      validation_succeeded = true
      kong.log.debug("SOAPMessageValidation: SOAP message validated successfully in phase '", phase, "'.")
    else
      kong.log.warn("SOAPMessageValidation: SOAP message validation failed. Details: ", service_response.details or "No details.")
    end
  end

  if not validation_succeeded then
    if not conf.on_validation_failure_continue then
      return kong.response.exit(conf.on_validation_failure_status, conf.on_validation_failure_body)
    end
    kong.log.warn("SOAPMessageValidation: Validation failed but 'on_validation_failure_continue' is true. Continuing processing.")
  end
  return true
end


function SOAPMessageValidationHandler:access(conf)
  SOAPMessageValidationHandler.super.access(self)
  -- Only validate request body or shared context for request-side
  if conf.message_source_type == "request_body" or conf.message_source_type == "shared_context" then
    return perform_validation(self, conf, "access")
  end
  return true
end

function SOAPMessageValidationHandler:body_filter(conf)
  SOAPMessageValidationHandler.super.body_filter(self)
  -- Only validate response body or shared context for response-side
  if conf.message_source_type == "response_body" or conf.message_source_type == "shared_context" then
    return perform_validation(self, conf, "body_filter")
  end
  return true
end

return SOAPMessageValidationHandler
