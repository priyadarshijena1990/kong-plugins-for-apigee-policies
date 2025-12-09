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

-- Helper to set value in JSON body using simple dot notation
local function set_json_value(json_table, path, value)
  if not json_table or not path or path == "" then
    return false
  end
  local parts = {}
  for part in path:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  local current = json_table
  for i, part in ipairs(parts) do
    if i == #parts then
      current[part] = value
      return true
    else
      if type(current[part]) ~= "table" then
        current[part] = {}
      end
      current = current[part]
    end
  end
  return false
end

-- Helper to get a string value from various sources
local function get_value_from_source(source_type, source_name)
  local value = nil
  if source_type == "header" then
    value = kong.request.get_header(source_name)
  elseif source_type == "query" then
    value = kong.request.get_query_arg(source_name)
  elseif source_type == "body" then
    local raw_body = kong.request.get_raw_body()
    if raw_body then
      local ok, parsed_body = pcall(cjson.decode, raw_body)
      if ok then
        value = get_json_value(parsed_body, source_name)
      else
        kong.log.warn("SAMLAssertion: Could not decode request body as JSON for source '", source_name, "'.")
      end
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  elseif source_type == "literal" then
    value = source_name
  end
  return value
end

-- Helper to set a string value to various destinations
local function set_value_to_destination(destination_type, destination_name, value)
  if not value then value = "" end

  if destination_type == "header" then
    kong.request.set_header(destination_name, tostring(value))
  elseif destination_type == "query" then
    kong.request.set_query_arg(destination_name, tostring(value))
  elseif destination_type == "body" then
    local current_body = kong.request.get_raw_body()
    local parsed_body, err = cjson.decode(current_body or "{}")
    if not parsed_body then
      kong.log.warn("SAMLAssertion: Could not decode existing request body for SAML destination. Creating new body.")
      parsed_body = {}
    end

    if destination_name == "." or destination_name == "" then
      kong.request.set_body(tostring(value))
      kong.request.set_header("Content-Type", "application/xml") -- SAML is XML
    else
      set_json_value(parsed_body, destination_name, value)
      kong.request.set_body(cjson.encode(parsed_body))
      kong.request.set_header("Content-Type", "application/json")
    end
  elseif destination_type == "shared_context" then
    kong.ctx.shared[destination_name] = value
  end
end

local SAMLAssertionHandler = BasePlugin:extend("saml_assertion")

function SAMLAssertionHandler:new()
  return SAMLAssertionHandler.super.new(self, "saml_assertion")
end

function SAMLAssertionHandler:access(conf)
  SAMLAssertionHandler.super.access(self)

  local request_body_for_service = {}
  local saml_operation_successful = false

  if conf.operation_type == "generate" then
    local payload_content = get_value_from_source(conf.saml_payload_source_type, conf.saml_payload_source_name)
    local signing_key = nil
    if conf.signing_key_source_type == "literal" then signing_key = conf.signing_key_literal
    elseif conf.signing_key_source_type == "shared_context" then signing_key = get_value_from_source("shared_context", conf.signing_key_source_name) end

    if not payload_content or not signing_key then
      kong.log.err("SAMLAssertion: Missing payload or signing key for SAML generation.")
      if not conf.on_error_continue then return kong.response.exit(conf.on_error_status, conf.on_error_body) end
      return
    end

    request_body_for_service = {
      operation = "generate",
      payload = payload_content,
      signing_key = signing_key,
    }

  elseif conf.operation_type == "verify" then
    local saml_assertion = get_value_from_source(conf.saml_assertion_source_type, conf.saml_assertion_source_name)
    local verification_key = nil
    if conf.verification_key_source_type == "literal" then verification_key = conf.verification_key_literal
    elseif conf.verification_key_source_type == "shared_context" then verification_key = get_value_from_source("shared_context", conf.verification_key_source_name) end

    if not saml_assertion or not verification_key then
      kong.log.err("SAMLAssertion: Missing SAML assertion or verification key for SAML verification.")
      if not conf.on_error_continue then return kong.response.exit(conf.on_error_status, conf.on_error_body) end
      return
    end

    request_body_for_service = {
      operation = "verify",
      saml_assertion = saml_assertion,
      verification_key = verification_key,
    }
  end

  local callout_opts = {
    method = "POST",
    headers = { ["Content-Type"] = "application/json" },
    body = cjson.encode(request_body_for_service),
    timeout = 10000,
    connect_timeout = 5000,
    ssl_verify = true,
  }

  local res, err = kong.http.client.go(conf.saml_service_url, callout_opts)

  if not res then
    kong.log.err("SAMLAssertion: Call to SAML service '", conf.saml_service_url, "' failed: ", err)
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  if res.status ~= 200 then
    kong.log.err("SAMLAssertion: SAML service '", conf.saml_service_url, "' returned error status: ", res.status, " Body: ", res.body)
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  local service_response, decode_err = cjson.decode(res.body)
  if not service_response then
    kong.log.err("SAMLAssertion: Failed to decode JSON response from SAML service. Error: ", decode_err)
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  if service_response.success == true then
    saml_operation_successful = true
    if conf.operation_type == "generate" and service_response.saml_assertion then
      set_value_to_destination(conf.output_destination_type, conf.output_destination_name, service_response.saml_assertion)
      kong.log.debug("SAMLAssertion: Generated SAML assertion and stored.")
    elseif conf.operation_type == "verify" and service_response.verified == true then
      kong.log.debug("SAMLAssertion: SAML assertion verified successfully.")
      -- Extract claims
      if service_response.attributes and type(service_response.attributes) == "table" then
        for _, claim_mapping in ipairs(conf.extract_claims) do
          local attribute_value = service_response.attributes[claim_mapping.attribute_name]
          if attribute_value ~= nil then
            kong.ctx.shared[claim_mapping.output_key] = attribute_value
            kong.log.debug("SAMLAssertion: Extracted SAML attribute '", claim_mapping.attribute_name, "' to '", claim_mapping.output_key, "': ", tostring(attribute_value))
          else
            kong.log.debug("SAMLAssertion: SAML attribute '", claim_mapping.attribute_name, "' not found in service response.")
          end
        end
      end
    else
      saml_operation_successful = false -- Service indicated success but didn't provide expected data
      kong.log.err("SAMLAssertion: SAML service response successful but missing expected data.")
    end
  else -- Service response.success is false or not true
    kong.log.err("SAMLAssertion: SAML service reported failure. Message: ", service_response.message or "No message.")
  end

  if not saml_operation_successful and not conf.on_error_continue then
    return kong.response.exit(conf.on_error_status, conf.on_error_body)
  elseif not saml_operation_successful and conf.on_error_continue then
    kong.log.warn("SAMLAssertion: SAML operation failed but 'on_error_continue' is true. Continuing request processing.")
  end
end

return SAMLAssertionHandler
