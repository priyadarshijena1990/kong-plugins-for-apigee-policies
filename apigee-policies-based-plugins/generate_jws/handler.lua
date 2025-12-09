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

-- Helper to get a value from various sources
local function get_value_from_source(source_type, source_name)
  if source_type == "literal" then
    return source_name
  end
  local value
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
        value = raw_body -- Not JSON, treat as plain text
      end
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  end
  return value
end

-- Helper to set a string value to various destinations
local function set_value_to_destination(destination_type, destination_name, value)
  if destination_type == "header" then
    kong.request.set_header(destination_name, value)
  elseif destination_type == "query" then
    kong.request.set_query({ [destination_name] = value })
  elseif destination_type == "body" then
    local current_body = kong.request.get_raw_body()
    local parsed_body, err = pcall(cjson.decode, current_body or "{}")
    if not parsed_body or err then
      parsed_body = {}
    end
    if destination_name == "." or destination_name == "" then
      kong.request.set_body(value, "application/jwt")
    else
      set_json_value(parsed_body, destination_name, value)
      kong.request.set_body(cjson.encode(parsed_body), "application/json")
    end
  elseif destination_type == "shared_context" then
    kong.ctx.shared[destination_name] = value
  end
end

local GenerateJWSHandler = {
  PRIORITY = 1000,
}

function GenerateJWSHandler:access(conf)
  local payload_content = get_value_from_source(conf.payload_source_type, conf.payload_source_name)
  if payload_content == nil then
    kong.log.err("GenerateJWS: No payload content found from source '", conf.payload_source_type, ":", (conf.payload_source_name or "n/a"), "'")
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end
  
  -- The JWT library expects the payload to be a Lua table.
  -- If we got a JSON string, decode it.
  local payload_table = payload_content
  if type(payload_content) == "string" then
    local ok, decoded = pcall(cjson.decode, payload_content)
    if ok then
      payload_table = decoded
    else
      -- If it's not JSON, the library might handle it as a raw string payload.
      -- For JWS, this is valid. Let's wrap it if it's not a table.
      if type(payload_table) ~= "table" then
        payload_table = { payload = payload_table }
      end
    end
  end

  if type(payload_table) ~= "table" then
      kong.log.err("GenerateJWS: Payload must be a JSON object/string or a Lua table.")
      if not conf.on_error_continue then
        return kong.response.exit(conf.on_error_status, "Payload must be a JSON object/string or a Lua table.")
      end
      return
  end

  local private_key_string = get_value_from_source(conf.private_key_source_type, conf.private_key_literal or conf.private_key_source_name)
  if not private_key_string then
    kong.log.err("GenerateJWS: No private key found from source '", conf.private_key_source_type, "'.")
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end
  
  local header = conf.jws_header_parameters or {}
  header.alg = conf.algorithm

  local jwt_obj = {
    header = header,
    payload = payload_table,
  }

  local jws_string, err = jwt:sign(private_key_string, jwt_obj)

  if not jws_string then
    kong.log.err("GenerateJWS: Failed to sign JWS. Error: ", tostring(err))
    if not conf.on_error_continue then
      return kong.response.exit(conf.on_error_status, conf.on_error_body)
    end
    return
  end

  set_value_to_destination(conf.output_destination_type, conf.output_destination_name, jws_string)

  kong.log.debug("GenerateJWS: JWS generated and stored successfully.")
end

return GenerateJWSHandler
