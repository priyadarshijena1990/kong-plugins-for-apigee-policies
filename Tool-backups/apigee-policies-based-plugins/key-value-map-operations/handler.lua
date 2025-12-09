local kong_meta = require "kong.meta"
local cjson = require "cjson"

local KvmOperationsHandler = {}

KvmOperationsHandler.PRIORITY = 950
KvmOperationsHandler.VERSION = kong_meta.version

-- Helper to extract a value from various sources
local function get_source_value(source_type, source_name)
  if source_type == "literal" then
    return source_name
  elseif source_type == "header" then
    return kong.request.get_header(source_name)
  elseif source_type == "query" then
    return (kong.request.get_query())[source_name]
  elseif source_type == "shared_context" then
    return kong.ctx.shared[source_name]
  elseif source_type == "body" then
    -- Note: This requires a JSON body and json-path style extraction.
    -- For simplicity, this example assumes a flat JSON structure.
    local body, err = kong.request.get_json()
    if err or not body then return nil end
    return body[source_name]
  end
  return nil
end

-- Helper to set a value to a destination
local function set_destination_value(dest_type, dest_name, value)
  if dest_type == "header" then
    kong.service.request.set_header(dest_name, value)
  elseif dest_type == "query" then
    kong.service.request.set_query({ [dest_name] = value })
  elseif dest_type == "shared_context" then
    kong.ctx.shared[dest_name] = value
  elseif dest_type == "body" then
    -- Note: This is complex. A simple implementation replaces the whole body.
    kong.service.request.set_body({ [dest_name] = value })
  end
end

local function handle_error(conf, message)
  kong.log.err(message)
  if not conf.on_error_continue then
    return kong.response.exit(conf.on_error_status, { message = message })
  end
end

-- Local Policy (lua_shared_dict) implementation
local local_policy = {
  get = function(conf, key)
    local dict = kong.shared[conf.kvm_name]
    if not dict then
      return nil, "Shared dictionary not found: " .. conf.kvm_name
    end
    return dict:get(key)
  end,

  put = function(conf, key, value)
    local dict = kong.shared[conf.kvm_name]
    if not dict then
      return nil, "Shared dictionary not found: " .. conf.kvm_name
    end
    local ok, err = dict:set(key, value, conf.ttl)
    if not ok then
      return nil, "Failed to set key in shared dictionary: " .. (err or "capacity exceeded")
    end
    return true
  end,

  delete = function(conf, key)
    local dict = kong.shared[conf.kvm_name]
    if not dict then
      return nil, "Shared dictionary not found: " .. conf.kvm_name
    end
    dict:delete(key)
    return true
  end
}

-- Cluster Policy (database) implementation
local cluster_policy = {
  get = function(conf, key)
    local row, err = kong.db.kvm_data:select({ kvm_name = conf.kvm_name, key = key })
    if err then
      return nil, "Database error on get: " .. err
    end
    if not row or (row.expires_at and row.expires_at <= ngx.time()) then
      if row then -- cleanup expired entry
        kong.db.kvm_data:delete({ id = row.id })
      end
      return nil -- Not found or expired
    end
    return row.value
  end,

  put = function(conf, key, value)
    local expires_at = nil
    if conf.ttl and conf.ttl > 0 then
      expires_at = ngx.time() + conf.ttl
    end

    local row, err = kong.db.kvm_data:upsert({
      kvm_name = conf.kvm_name,
      key = key,
    }, {
      value = value,
      expires_at = expires_at,
    })

    if err then
      return nil, "Database error on put: " .. err
    end
    return row
  end,

  delete = function(conf, key)
    local _, err = kong.db.kvm_data:delete({ kvm_name = conf.kvm_name, key = key })
    if err then
      return nil, "Database error on delete: " .. err
    end
    return true
  end
}

local policies = {
  local = local_policy,
  cluster = cluster_policy,
}

function KvmOperationsHandler:access(conf)
  local policy_impl = policies[conf.policy]
  if not policy_impl then
    return handle_error(conf, "Invalid KVM policy specified: " .. conf.policy)
  end

  -- 1. Get the key for the operation
  local key = get_source_value(conf.key_source_type, conf.key_source_name)
  if not key then
    return handle_error(conf, "KVM operation key not found or is empty.")
  end

  -- 2. Perform the operation
  if conf.operation_type == "get" then
    if not conf.output_destination_type or not conf.output_destination_name then
      return handle_error(conf, "'output_destination_type' and 'output_destination_name' are required for 'get' operation.")
    end

    local value, err = policy_impl.get(conf, key)
    if err then
      return handle_error(conf, err)
    end

    if value then
      set_destination_value(conf.output_destination_type, conf.output_destination_name, value)
    else
      -- Apigee compatibility: if key not found, do nothing.
      kong.log.debug("KVM key not found: ", key)
    end

  elseif conf.operation_type == "put" then
    if not conf.value_source_type or not conf.value_source_name then
      return handle_error(conf, "'value_source_type' and 'value_source_name' are required for 'put' operation.")
    end

    local value = get_source_value(conf.value_source_type, conf.value_source_name)
    if value == nil then -- Allow empty strings, but not nil
      return handle_error(conf, "KVM value for 'put' operation not found.")
    end

    local ok, err = policy_impl.put(conf, key, value)
    if err then
      return handle_error(conf, err)
    end

  elseif conf.operation_type == "delete" then
    local ok, err = policy_impl.delete(conf, key)
    if err then
      return handle_error(conf, err)
    end
  end
end

-- Since this plugin modifies the request, it should run in the `access` phase.
-- We don't need other phases like `rewrite` or `preread`.

return KvmOperationsHandler