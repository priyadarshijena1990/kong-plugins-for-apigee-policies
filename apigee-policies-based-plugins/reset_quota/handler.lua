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
        kong.log.warn("ResetQuota: Could not decode request body as JSON for source '", source_name, "'.")
      end
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  elseif source_type == "literal" then
    value = source_name
  end
  return value
end

local ResetQuotaHandler = BasePlugin:extend("reset-quota")

function ResetQuotaHandler:new()
  return ResetQuotaHandler.super.new(self, "reset-quota")
end

function ResetQuotaHandler:access(conf)
  ResetQuotaHandler.super.access(self)

  local scope_id = nil
  if conf.scope_type then
    if not conf.scope_id_source_type or not conf.scope_id_source_name then
      kong.log.err("ResetQuota: 'scope_id_source_type' and 'scope_id_source_name' are required when 'scope_type' is set.")
      if not conf.on_error_continue then
        return kong.response.exit(conf.on_error_status, conf.on_error_body)
      end
      return
    end
    scope_id = get_value_from_source(conf.scope_id_source_type, conf.scope_id_source_name)
    if not scope_id or scope_id == "" then
      kong.log.err("ResetQuota: Could not retrieve scope ID from source '", conf.scope_id_source_type, ":", conf.scope_id_source_name, "'.")
      if not conf.on_error_continue then
        return kong.response.exit(conf.on_error_status, conf.on_error_body)
      end
      return
    end
  end

  local admin_api_reset_url = string.format(
    "%s/plugins/%s/rate-limit",
    conf.admin_api_url,
    conf.rate_limiting_plugin_id
  )

  if scope_id then
    admin_api_reset_url = string.format("%s/%s/reset", admin_api_reset_url, scope_id)
  else
    admin_api_reset_url = admin_api_reset_url .. "/reset"
  end

  local headers = {}
  if conf.admin_api_key then
    headers["apikey"] = conf.admin_api_key
  end

  local callout_opts = {
    method = "DELETE",
    headers = headers,
    timeout = 10000,
    connect_timeout = 5000,
    ssl_verify = true,
  }

  local res, err = kong.http.client.go(admin_api_reset_url, callout_opts)

  local reset_succeeded = true
  if not res then
    reset_succeeded = false
    kong.log.err("ResetQuota: Failed to call Kong Admin API for reset '", admin_api_reset_url, "'. Error: ", err)
  elseif res.status ~= 204 then -- 204 No Content is common for successful DELETE
    reset_succeeded = false
    kong.log.err("ResetQuota: Kong Admin API returned error status: ", res.status, " Body: ", res.body)
  else
    kong.log.debug("ResetQuota: Successfully reset quota for plugin ID '", conf.rate_limiting_plugin_id, "' (Scope: ", (scope_id or "global"), ").")
  end

  if not reset_succeeded and not conf.on_error_continue then
    return kong.response.exit(conf.on_error_status, conf.on_error_body)
  elseif not reset_succeeded and conf.on_error_continue then
    kong.log.warn("ResetQuota: Quota reset failed but 'on_error_continue' is true. Continuing request processing.")
  end
end

return ResetQuotaHandler
