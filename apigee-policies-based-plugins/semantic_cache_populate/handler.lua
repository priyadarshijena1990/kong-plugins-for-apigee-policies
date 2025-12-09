local BasePlugin = require "kong.plugins.base_plugin"
local fun = require "kong.tools.functional"

-- Helper function to resolve fragment values from different sources
local function resolve_fragment_value(fragment_ref)
  if fragment_ref == "request.uri" then
    return kong.request.get_uri()
  elseif fragment_ref == "request.method" then
    return kong.request.get_method()
  elseif fragment_ref:sub(1, 15) == "request.headers." then
    local header_name = fragment_ref:sub(16)
    return kong.request.get_header(header_name)
  elseif fragment_ref:sub(1, 19) == "request.query_param." then
    local query_param_name = fragment_ref:sub(20)
    return kong.request.get_query_arg(query_param_name)
  elseif fragment_ref:sub(1, 15) == "shared_context." then
    local shared_key = fragment_ref:sub(16)
    local value = kong.ctx.shared[shared_key]
    -- Ensure tables are serialized for key consistency
    if type(value) == "table" then
      local ok, json_value = pcall(kong.json.encode, value)
      if ok then
        return json_value
      else
        kong.log.warn("SemanticCachePopulate: Failed to JSON encode shared_context value for key '", shared_key, "' for cache key generation.")
        return tostring(value) -- Fallback to string representation
      end
    end
    return value
  else
    return fragment_ref -- Treat as literal
  end
end

local SemanticCachePopulateHandler = BasePlugin:extend("semantic-cache-populate")

function SemanticCachePopulateHandler:new()
  return SemanticCachePopulateHandler.super.new(self, "semantic-cache-populate")
end

function SemanticCachePopulateHandler:body_filter(conf)
  SemanticCachePopulateHandler.super.body_filter(self)

  local cache_key_parts = {}
  if conf.cache_key_prefix ~= "" then
    table.insert(cache_key_parts, conf.cache_key_prefix)
  end

  for _, fragment_ref in ipairs(conf.cache_key_fragments) do
    local value = resolve_fragment_value(fragment_ref)
    if value then
      table.insert(cache_key_parts, tostring(value))
    else
      kong.log.warn("SemanticCachePopulate: Could not resolve cache key fragment: ", fragment_ref)
    end
  end

  local cache_key = table.concat(cache_key_parts, ":")
  if cache_key == "" then
    kong.log.err("SemanticCachePopulate: Generated cache key is empty. Aborting cache population.")
    return
  end

  local cache_content = nil
  if conf.source == "response_body" then
    cache_content = kong.response.get_raw_body()
  elseif conf.source == "shared_context" then
    if conf.shared_context_key then
      cache_content = kong.ctx.shared[conf.shared_context_key]
      -- If the shared context value is a table, serialize it to JSON
      if type(cache_content) == "table" then
        local ok, json_content = pcall(kong.json.encode, cache_content)
        if ok then
          cache_content = json_content
        else
          kong.log.err("SemanticCachePopulate: Failed to JSON encode content from shared_context key '", conf.shared_context_key, "'. Aborting cache population.")
          return
        end
      end
    else
      kong.log.err("SemanticCachePopulate: 'shared_context_key' is required when 'source' is 'shared_context'. Aborting cache population.")
      return
    end
  end

  if not cache_content or cache_content == "" then
    kong.log.warn("SemanticCachePopulate: Cache content is empty or nil. Aborting cache population for key: ", cache_key)
    return
  end

  local ok, err = kong.cache.set(cache_key, cache_content, conf.cache_ttl)
  if ok then
    kong.log.debug("SemanticCachePopulate: Successfully populated cache for key: ", cache_key, " with TTL: ", conf.cache_ttl)
  else
    kong.log.err("SemanticCachePopulate: Failed to populate cache for key: ", cache_key, ". Error: ", err)
  end
end

return SemanticCachePopulateHandler
