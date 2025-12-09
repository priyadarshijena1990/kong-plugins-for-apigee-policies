local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local fun = require "kong.tools.functional"
local util = require "kong.tools.utils"

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

-- Helper to get the token from various sources
local function get_token_from_source(conf)
  local token = nil
  local request_body = nil
  local parsed_body = nil

  if conf.token_source_type == "header" then
    token = kong.request.get_header(conf.token_source_name)
    -- Handle Authorization: Bearer token_string
    if token and token:lower():sub(1, 7) == "bearer " then
      token = token:sub(8)
    end
  elseif conf.token_source_type == "query" then
    token = kong.request.get_query_arg(conf.token_source_name)
  elseif conf.token_source_type == "body" then
    request_body = kong.request.get_raw_body()
    if request_body then
      local ok, decoded = pcall(cjson.decode, request_body)
      if ok then
        parsed_body = decoded
        token = get_json_value(parsed_body, conf.token_source_name)
      else
        kong.log.warn("RevokeOAuthV2: Could not decode request body as JSON for token source.")
      end
    end
  elseif conf.token_source_type == "shared_context" then
    token = kong.ctx.shared[conf.token_source_name]
  end

  return token and tostring(token) or nil
end

local RevokeOAuthV2Handler = BasePlugin:extend("revoke-oauth-v2")

function RevokeOAuthV2Handler:new()
  return RevokeOAuthV2Handler.super.new(self, "revoke-oauth-v2")
end

function RevokeOAuthV2Handler:access(conf)
  RevokeOAuthV2Handler.super.access(self)

  local token_to_revoke = get_token_from_source(conf)

  if not token_to_revoke or token_to_revoke == "" then
    kong.log.err("RevokeOAuthV2: No token found for revocation from source '", conf.token_source_type, ":", conf.token_source_name, "'")
    return kong.response.exit(400, "Missing token for revocation.")
  end

  local form_params = {
    token = token_to_revoke,
  }
  if conf.token_type_hint then
    form_params.token_type_hint = conf.token_type_hint
  end

  local headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded",
  }

  -- Handle client credentials for authentication
  if conf.client_id and conf.client_secret then
    local basic_auth_string = conf.client_id .. ":" .. conf.client_secret
    headers["Authorization"] = "Basic " .. util.encode_base64(basic_auth_string)
  elseif conf.client_id then
    -- If only client_id, include as form param
    form_params.client_id = conf.client_id
  end

  local callout_opts = {
    method = "POST",
    headers = headers,
    body = util.encode_urlencoded(form_params),
    timeout = 10000,          -- Default timeout for callout
    connect_timeout = 5000,
    ssl_verify = true,
  }

  local res, err = kong.http.client.go(conf.revocation_endpoint, callout_opts)

  if not res then
    kong.log.err("RevokeOAuthV2: Failed to connect to revocation endpoint '", conf.revocation_endpoint, "': ", err)
    return kong.response.exit(conf.on_error_status, conf.on_error_body)
  end

  if res.status >= 200 and res.status < 300 then -- OAuth spec typically returns 200 for successful revocation
    kong.log.debug("RevokeOAuthV2: Token successfully revoked via endpoint '", conf.revocation_endpoint, "'. Status: ", res.status)
    return kong.response.exit(conf.on_success_status, conf.on_success_body)
  else
    kong.log.err("RevokeOAuthV2: Revocation endpoint '", conf.revocation_endpoint, "' returned error status: ", res.status, " Body: ", res.body)
    return kong.response.exit(conf.on_error_status, conf.on_error_body)
  end
end

return RevokeOAuthV2Handler
