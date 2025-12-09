local cjson = require "cjson"

-- Helper to safely get value from JSON body using simple dot notation
local function get_json_value(json_table, path)
  if not json_table or not path or path == "" then
    return json_table -- Return whole table if path is empty/root
  end
  
  local current = json_table
  for part in path:gmatch("[^.]+") do
    if type(current) == "table" and current[part] ~= nil then
      current = current[part]
    else
      return nil -- Path not found
    end
  end
  return current
end

-- Helper to get a string value from various sources
local function get_value_from_source(source_type, source_name)
  local value = nil
  if source_type == "header" then
    value = kong.request.get_header(source_name)
    -- Handle Authorization: Bearer token_string, etc. if applicable
    if value and source_name:lower() == "authorization" and value:lower():sub(1, 7) == "bearer " then
      value = value:sub(8)
    end
  elseif source_type == "query" then
    value = kong.request.get_query_arg(source_name)
  elseif source_type == "body" then
    local raw_body = kong.request.get_raw_body()
    if raw_body then
      local ok, parsed_body = pcall(cjson.decode, raw_body)
      if ok then
        value = get_json_value(parsed_body, source_name)
      else
        kong.log.warn("DecodeJWS: Could not decode request body as JSON for source '", source_name, "'.")
      end
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  elseif source_type == "literal" then -- Used for public_key_literal
    value = source_name
  end
  return value and tostring(value) or nil
end

local DecodeJWSHandler = {
  PRIORITY = 1000
}

function DecodeJWSHandler:access(conf)
  local jws_string = get_value_from_source(conf.jws_source_type, conf.jws_source_name)
  if not jws_string or jws_string == "" then
    kong.log.err("DecodeJWS: No JWS string found from source '", conf.jws_source_type, ":", conf.jws_source_name, "'")
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  local public_key_string = nil
  if conf.public_key_source_type == "literal" then
    public_key_string = conf.public_key_literal
  elseif conf.public_key_source_type == "shared_context" then
    public_key_string = get_value_from_source("shared_context", conf.public_key_source_name)
  end

  if not public_key_string or public_key_string == "" then
    kong.log.err("DecodeJWS: No public key found from source '", conf.public_key_source_type, ":", (conf.public_key_literal or conf.public_key_source_name), "'")
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  local request_body_for_service = cjson.encode({
    jws = jws_string,
    public_key = public_key_string,
  })

  local res, err = kong.http.client.request({
    method = "POST",
    url = conf.jws_decode_service_url,
    headers = { ["Content-Type"] = "application/json" },
    body = request_body_for_service,
    timeout = 10000,
    connect_timeout = 5000,
    ssl_verify = true,
  })

  if not res then
    kong.log.err("DecodeJWS: Call to JWS decode service '", conf.jws_decode_service_url, "' failed: ", err)
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  local body, body_err = res:read_body()
  if body_err then
    kong.log.err("DecodeJWS: JWS decode service '", conf.jws_decode_service_url, "' failed to read body: ", body_err)
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end
  
  if res.status ~= 200 then
    kong.log.err("DecodeJWS: JWS decode service '", conf.jws_decode_service_url, "' returned error status: ", res.status, " Body: ", body)
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  local service_response, decode_err = cjson.decode(body)
  if not service_response then
    kong.log.err("DecodeJWS: Failed to decode JSON response from JWS decode service. Error: ", decode_err)
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  -- Assuming service_response contains { "header": {}, "payload": {} }
  local payload_claims = service_response.payload
  if not payload_claims then
    kong.log.err("DecodeJWS: JWS decode service response missing 'payload' claims.")
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  for _, claim_mapping in ipairs(conf.claims_to_extract) do
    local claim_value = payload_claims[claim_mapping.claim_name]
    if claim_value ~= nil then
      kong.ctx.shared[claim_mapping.output_key] = claim_value
      kong.log.debug("DecodeJWS: Extracted claim '", claim_mapping.claim_name, "' to '", claim_mapping.output_key, "': ", tostring(claim_value))
    else
      kong.log.debug("DecodeJWS: Claim '", claim_mapping.claim_name, "' not found in JWS payload.")
    end
  end

  kong.log.debug("DecodeJWS: JWS decoded and claims extracted.")
end

return DecodeJWSHandler
