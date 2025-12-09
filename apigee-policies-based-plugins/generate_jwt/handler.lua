local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local jwt = require "resty.jwt"

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
    if raw_body and raw_body ~= "" then
      local ok, parsed_body = pcall(cjson.decode, raw_body)
      if ok then
        value = get_json_value(parsed_body, source_name)
      else
        kong.log.warn("GenerateJWT: Could not decode request body as JSON for source '", source_name, "'.")
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
  if destination_type == "header" then
    kong.service.request.set_header(destination_name, value)
  elseif destination_type == "query" then
    kong.service.request.set_query({ [destination_name] = value })
  elseif destination_type == "body" then
    local current_body = kong.request.get_raw_body()
    local parsed_body, err = pcall(cjson.decode, current_body or "{}")
    if not parsed_body or err then
      parsed_body = {}
    end

    if destination_name == "." or destination_name == "" then
      kong.service.request.set_body(value)
      kong.service.request.set_header("Content-Type", "application/jwt")
    else
      set_json_value(parsed_body, destination_name, value)
      kong.service.request.set_body(cjson.encode(parsed_body))
      kong.service.request.set_header("Content-Type", "application/json")
    end
  elseif destination_type == "shared_context" then
    kong.ctx.shared[destination_name] = value
  end
end


local GenerateJWTHandler = BasePlugin:extend("generate-jwt")
GenerateJWTHandler.PRIORITY = 1000

function GenerateJWTHandler:new()
  GenerateJWTHandler.super.new(self)
end

function GenerateJWTHandler:access(conf)
  GenerateJWTHandler.super.access(self)

  local claims_payload = {}
  local signing_key = nil

  -- Timestamps
  claims_payload.iat = ngx.time()
  if conf.expires_in_seconds then
    claims_payload.exp = ngx.time() + conf.expires_in_seconds
  end

  -- Standard claims
  if conf.subject_source_type then claims_payload.sub = get_value_from_source(conf.subject_source_type, conf.subject_source_name) end
  if conf.issuer_source_type then claims_payload.iss = get_value_from_source(conf.issuer_source_type, conf.issuer_source_name) end
  if conf.audience_source_type then claims_payload.aud = get_value_from_source(conf.audience_source_type, conf.audience_source_name) end

  -- Additional claims
  if conf.additional_claims then
    for _, claim_conf in ipairs(conf.additional_claims) do
      claims_payload[claim_conf.claim_name] = get_value_from_source(claim_conf.claim_value_source_type, claim_conf.claim_value_source_name)
    end
  end

  -- Signing key
  if conf.algorithm:sub(1, 2) == "HS" then -- HS algorithms use secret
    if conf.secret_source_type == "literal" then
      signing_key = conf.secret_literal
    elseif conf.secret_source_type == "shared_context" then
      signing_key = get_value_from_source("shared_context", conf.secret_source_name)
    end
    if not signing_key then
      kong.log.err("GenerateJWT: Secret key not found for HS algorithm.")
      if not conf.on_error_continue then return kong.response.exit(conf.on_error_status, conf.on_error_body) end
      return
    end
  elseif conf.algorithm:sub(1, 2) == "RS" or conf.algorithm:sub(1, 2) == "ES" then -- RS/ES algorithms use private key
    if conf.private_key_source_type == "literal" then
      signing_key = conf.private_key_literal
    elseif conf.private_key_source_type == "shared_context" then
      signing_key = get_value_from_source("shared_context", conf.private_key_source_name)
    end
    if not signing_key then
      kong.log.err("GenerateJWT: Private key not found for RS/ES algorithm.")
      if not conf.on_error_continue then return kong.response.exit(conf.on_error_status, conf.on_error_body) end
      return
    end
  end

  -- Assemble and sign the JWT
  local header = conf.jws_header_parameters or {}
  header.alg = conf.algorithm

  local jwt_obj = {
    header = header,
    payload = claims_payload,
  }

  local jwt_string, err = jwt:sign(signing_key, jwt_obj)

  if not jwt_string then
    kong.log.err("GenerateJWT: Failed to sign JWT. Error: ", tostring(err))
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  set_value_to_destination(conf.output_destination_type, conf.output_destination_name, jwt_string)

  kong.log.debug("GenerateJWT: JWT generated and stored successfully.")
end

return GenerateJWTHandler
