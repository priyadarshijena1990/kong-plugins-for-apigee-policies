local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"

-- Helper to safely get value from JSON body using simple dot notation
local function get_json_value(json_table, path)
  if not json_table or not path or path == "" then
    return json_table
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
      return nil
    end
  end
  return current
end

-- Helper to get a string value from various sources for string-to-sign components
local function get_component_value(component_type, component_name)
  if component_type == "method" then
    return kong.request.get_method()
  elseif component_type == "uri" then
    return kong.request.get_path_with_query()
  elseif component_type == "header" then
    return kong.request.get_header(component_name) or ""
  elseif component_type == "query" then
    return kong.request.get_query_arg(component_name) or ""
  elseif component_type == "body" then
    local raw_body = kong.request.get_raw_body()
    if not raw_body or raw_body == "" then return "" end

    if component_name and component_name ~= "" and component_name ~= "." then
      local ok, parsed_body = pcall(cjson.decode, raw_body)
      if ok then
        return get_json_value(parsed_body, component_name) or ""
      end
    end
    return raw_body -- Use entire raw body
  elseif component_type == "literal" then
    return component_name or ""
  end
  return "" -- Return empty string if value is nil or not found
end

-- Helper to set a string value to various destinations
local function set_value_to_destination(destination_type, destination_name, value)
  if destination_type == "header" then
    kong.service.request.set_header(destination_name, value)
  elseif destination_type == "shared_context" then
    kong.ctx.shared[destination_name] = value
  end
end

-- Map algorithm names to ngx.hmac constants
local ALGORITHM_MAP = {
  ["HMAC-SHA1"]   = "sha1",
  ["HMAC-SHA256"] = "sha256",
  ["HMAC-SHA512"] = "sha512",
}

local HMACHandler = BasePlugin:extend("hmac")
HMACHandler.PRIORITY = 1000

function HMACHandler:new()
  HMACHandler.super.new(self)
end

function HMACHandler:access(conf)
  HMACHandler.super.access(self)

  -- 1. Retrieve shared secret
  local secret_string
  if conf.secret_source_type == "literal" then
    secret_string = conf.secret_literal
  elseif conf.secret_source_type == "shared_context" then
    secret_string = kong.ctx.shared[conf.secret_source_name]
  end

  if not secret_string or secret_string == "" then
    kong.log.err("HMAC: Shared secret not found.")
    if conf.mode == "verify" and not conf.on_verification_failure_continue then
      return kong.response.exit(conf.on_verification_failure_status, conf.on_verification_failure_body)
    end
    return
  end
  secret_string = tostring(secret_string)

  -- 2. Construct String-to-Sign
  local string_to_sign_parts = {}
  for _, component in ipairs(conf.string_to_sign_components) do
    table.insert(string_to_sign_parts, get_component_value(component.component_type, component.component_name))
  end
  local string_to_sign = table.concat(string_to_sign_parts, "\n")

  -- 3. Calculate HMAC
  local algo = ALGORITHM_MAP[conf.algorithm]
  if not algo then
    kong.log.err("HMAC: Unsupported algorithm: ", conf.algorithm)
    return kong.response.exit(500, "Unsupported HMAC algorithm configured.")
  end

  local calculated_hmac, err = ngx.hmac_sha1(secret_string, string_to_sign)
  if algo == "sha256" then
    calculated_hmac, err = ngx.hmac_sha256(secret_string, string_to_sign)
  elseif algo == "sha512" then
    calculated_hmac, err = ngx.hmac_sha512(secret_string, string_to_sign)
  end

  if not calculated_hmac then
      kong.log.err("HMAC: Failed to calculate HMAC: ", err)
      return kong.response.exit(500, "Internal HMAC calculation error.")
  end
  
  local calculated_hmac_b64 = ngx.encode_base64(calculated_hmac)

  -- 4. Execute mode-specific logic
  if conf.mode == "verify" then
    local client_signature_header = kong.request.get_header(conf.signature_header_name)
    if not client_signature_header then
      kong.log.warn("HMAC: Client signature header '", conf.signature_header_name, "' not found.")
      if not conf.on_verification_failure_continue then
        return kong.response.exit(conf.on_verification_failure_status, conf.on_verification_failure_body)
      end
      return
    end

    local client_signature = client_signature_header
    if conf.signature_prefix and conf.signature_prefix ~= "" and client_signature:sub(1, #conf.signature_prefix) == conf.signature_prefix then
      client_signature = client_signature:sub(#conf.signature_prefix + 1)
    end

    if calculated_hmac_b64 == client_signature then
      kong.log.debug("HMAC: Signature verified successfully.")
    else
      kong.log.warn("HMAC: Signature verification failed.")
      if not conf.on_verification_failure_continue then
        return kong.response.exit(conf.on_verification_failure_status, conf.on_verification_failure_body)
      end
    end

  elseif conf.mode == "generate" then
    if not conf.output_destination_type or not conf.output_destination_name then
        kong.log.err("HMAC: Output destination not configured for 'generate' mode.")
        return kong.response.exit(500, "HMAC plugin misconfigured for generate mode.")
    end
    set_value_to_destination(conf.output_destination_type, conf.output_destination_name, calculated_hmac_b64)
    kong.log.debug("HMAC: HMAC generated successfully.")
  end
end

return HMACHandler

