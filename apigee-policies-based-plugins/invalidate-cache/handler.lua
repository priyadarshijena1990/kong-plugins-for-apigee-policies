local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"

-- Helper function to resolve fragment values from different sources
local function resolve_fragment_value(fragment_ref)
  if fragment_ref == "request.uri" then
    return kong.request.get_uri()
  elseif fragment_ref == "request.method" then
    return kong.request.get_method()
  elseif fragment_ref:sub(1, 15) == "request.headers." then
    return kong.request.get_header(fragment_ref:sub(16))
  elseif fragment_ref:sub(1, 19) == "request.query_param." then
    return kong.request.get_query_arg(fragment_ref:sub(20))
  elseif fragment_ref:sub(1, 15) == "shared_context." then
    local val = kong.ctx.shared[fragment_ref:sub(16)]
    if type(val) == "table" then
      return cjson.encode(val) -- pcall not needed, let it error if cjson fails
    end
    return val
  end
  return fragment_ref -- Treat as literal
end

local InvalidateCacheHandler = BasePlugin:extend("invalidate-cache")
InvalidateCacheHandler.PRIORITY = 1000

function InvalidateCacheHandler:new()
  InvalidateCacheHandler.super.new(self)
end

function InvalidateCacheHandler:access(conf)
  InvalidateCacheHandler.super.access(self)

  if conf.purge_by_prefix then
    -- Bulk invalidation by prefix
    if not conf.cache_key_prefix or conf.cache_key_prefix == "" then
      kong.log.err("InvalidateCache: `cache_key_prefix` is required when `purge_by_prefix` is true.")
      if not conf.continue_on_invalidation then
        return kong.response.exit(conf.on_invalidation_failure_status, "Missing cache_key_prefix for prefix-based purge.")
      end
      return
    end

    -- This logic assumes the default `kong.cache` backend, which uses `ngx.shared.kong_cache`.
    -- This will not work if a custom cache is configured for the Kong data plane.
    local kong_cache_dict = ngx.shared.kong_cache
    if not kong_cache_dict then
        kong.log.err("InvalidateCache: Could not access the default shared cache 'kong_cache'.")
        if not conf.continue_on_invalidation then
          return kong.response.exit(conf.on_invalidation_failure_status, "Default Kong cache not accessible.")
        end
        return
    end

    local keys, err = kong_cache_dict:get_keys()
    if not keys then
        kong.log.err("InvalidateCache: Could not retrieve keys from shared cache. Error: ", err)
        if not conf.continue_on_invalidation then
          return kong.response.exit(conf.on_invalidation_failure_status, "Could not retrieve cache keys.")
        end
        return
    end

    local invalidated_count = 0
    local prefix = conf.cache_key_prefix
    for _, key in ipairs(keys) do
        if key:sub(1, #prefix) == prefix then
            kong_cache_dict:delete(key)
            invalidated_count = invalidated_count + 1
        end
    end

    kong.log.debug("InvalidateCache: Invalidated ", invalidated_count, " entries with prefix '", prefix, "'.")
    if not conf.continue_on_invalidation then
      return kong.response.exit(conf.on_invalidation_success_status, conf.on_invalidation_success_body)
    end

  else
    -- Single key invalidation
    local cache_key_parts = {}
    if conf.cache_key_prefix and conf.cache_key_prefix ~= "" then
      table.insert(cache_key_parts, conf.cache_key_prefix)
    end

    for _, fragment_ref in ipairs(conf.cache_key_fragments) do
      local value = resolve_fragment_value(fragment_ref)
      if value ~= nil then
        table.insert(cache_key_parts, tostring(value))
      else
        kong.log.warn("InvalidateCache: Could not resolve cache key fragment: ", fragment_ref)
      end
    end

    local cache_key = table.concat(cache_key_parts, ":")
    if cache_key == "" then
      kong.log.err("InvalidateCache: Generated cache key is empty. Aborting.")
      if not conf.continue_on_invalidation then
        return kong.response.exit(conf.on_invalidation_failure_status, conf.on_invalidation_failure_body)
      end
      return
    end

    local invalidated, err = kong.cache.delete(cache_key)

    if invalidated then
      kong.log.debug("InvalidateCache: Successfully invalidated cache for key: ", cache_key)
      if not conf.continue_on_invalidation then
        return kong.response.exit(conf.on_invalidation_success_status, conf.on_invalidation_success_body)
      end
    else
      kong.log.warn("InvalidateCache: Failed to invalidate cache for key: ", cache_key, ". Reason: ", err or "key not found")
      if not conf.continue_on_invalidation then
        return kong.response.exit(conf.on_invalidation_failure_status, conf.on_invalidation_failure_body)
      end
    end
  end
end

return InvalidateCacheHandler
