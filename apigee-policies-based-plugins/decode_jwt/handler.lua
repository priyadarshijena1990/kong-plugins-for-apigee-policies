local cjson = require "cjson"
local jwt = require "resty.jwt"

-- Helper to safely get value from JSON body using simple dot notation
local function get_json_value(json_table, path)
  if not json_table or not path or path == "" then
    return json_table
  end
  
  local current = json_table
  for part in path:gmatch("[^.]+") do
    if type(current) == "table" and current[part] ~= nil then
      current = current[part]
    else
      return nil
    end
  end
  return current
end

-- Helper to get a string value from various sources
local function get_value_from_source(source_type, source_name)
  local value
  if source_type == "header" then
    value = kong.request.get_header(source_name)
    if value and source_name:lower() == "authorization" and value:lower():sub(1, 7) == "bearer " then
      value = value:sub(8)
    end
  elseif source_type == "query" then
    value = kong.request.get_query_arg(source_name)
  elseif source_type == "body" then
    local raw_body = kong.request.get_raw_body()
    if raw_body and raw_body ~= "" then
      local ok, parsed_body = pcall(cjson.decode, raw_body)
      if ok then
        value = get_json_value(parsed_body, source_name)
      else
        kong.log.warn("DecodeJWT: Could not decode request body as JSON for source '", source_name, "'.")
      end
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  end
  return value and tostring(value) or nil
end

local DecodeJWTHandler = {
  PRIORITY = 1000
}

function DecodeJWTHandler:access(conf)
  local jwt_string = get_value_from_source(conf.jwt_source_type, conf.jwt_source_name)
  if not jwt_string or jwt_string == "" then
    kong.log.err("DecodeJWT: No JWT string found from source '", conf.jwt_source_type, ":", conf.jwt_source_name, "'")
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  -- Use the library to decode the JWT without verification
  local decoded_jwt = jwt:load_jwt(jwt_string)

  if not decoded_jwt or not decoded_jwt.header or not decoded_jwt.payload then
    kong.log.err("DecodeJWT: Failed to decode JWT. It might be malformed.")
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  local decoded_header_table = decoded_jwt.header
  local decoded_payload_table = decoded_jwt.payload

  -- Store entire header and payload if configured
  if conf.store_header_to_shared_context_key then
    kong.ctx.shared[conf.store_header_to_shared_context_key] = decoded_header_table
    kong.log.debug("DecodeJWT: Stored decoded JWT header to shared context key: ", conf.store_header_to_shared_context_key)
  end
  if conf.store_all_claims_in_shared_context_key then
    kong.ctx.shared[conf.store_all_claims_in_shared_context_key] = decoded_payload_table
    kong.log.debug("DecodeJWT: Stored all decoded JWT claims to shared context key: ", conf.store_all_claims_in_shared_context_key)
  end

  -- Extract specific claims
  if conf.claims_to_extract then
    for _, claim_mapping in ipairs(conf.claims_to_extract) do
      local claim_value = decoded_payload_table[claim_mapping.claim_name]
      if claim_value ~= nil then
        kong.ctx.shared[claim_mapping.output_key] = claim_value
        kong.log.debug("DecodeJWT: Extracted claim '", claim_mapping.claim_name, "' to '", claim_mapping.output_key, "'")
      else
        kong.log.debug("DecodeJWT: Claim '", claim_mapping.claim_name, "' not found in JWT payload.")
      end
    end
  end

  kong.log.debug("DecodeJWT: JWT decoded successfully and claims extracted.")
end

return DecodeJWTHandler
