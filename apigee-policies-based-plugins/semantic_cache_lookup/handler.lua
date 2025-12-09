local BasePlugin = require "kong.plugins.base_plugin"
local fun = require "kong.tools.functional"

-- Helper function to resolve fragment values from different sources (reused from semantic-cache-populate)
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
        kong.log.warn("SemanticCacheLookup: Failed to JSON encode shared_context value for key '", shared_key, "' for cache key generation.")
        return tostring(value) -- Fallback to string representation
      end
    end
    return value
  else
    return fragment_ref -- Treat as literal
  end
end

local SemanticCacheLookupHandler = BasePlugin:extend("semantic-cache-lookup")

function SemanticCacheLookupHandler:new()
  return SemanticCacheLookupHandler.super.new(self, "semantic-cache-lookup")
end

function SemanticCacheLookupHandler:access(conf)
  SemanticCacheLookupHandler.super.access(self)

  local cache_key_parts = {}
  if conf.cache_key_prefix ~= "" then
    table.insert(cache_key_parts, conf.cache_key_prefix)
  end

  for _, fragment_ref in ipairs(conf.cache_key_fragments) do
    local value = resolve_fragment_value(fragment_ref)
    if value then
      table.insert(cache_key_parts, tostring(value))
    else
      kong.log.warn("SemanticCacheLookup: Could not resolve cache key fragment: ", fragment_ref)
    end
  end

  local cache_key = table.concat(cache_key_parts, ":")
  if cache_key == "" then
    kong.log.err("SemanticCacheLookup: Generated cache key is empty. Proceeding without cache lookup.")
    kong.response.set_header(conf.cache_hit_header_name, "MISS")
    return
  end

  local cached_content, err = kong.cache.get(cache_key)

  if cached_content then
    kong.log.debug("SemanticCacheLookup: Cache HIT for key: ", cache_key)
    if conf.assign_to_shared_context_key then
      kong.ctx.shared[conf.assign_to_shared_context_key] = cached_content
      kong.log.debug("SemanticCacheLookup: Stored cached content in shared context key: ", conf.assign_to_shared_context_key)
    end

    if conf.respond_from_cache_on_hit then
      kong.response.set_header(conf.cache_hit_header_name, "HIT")
      for header_name, header_value in pairs(conf.cache_hit_headers) do
        kong.response.set_header(header_name, header_value)
      end
      -- Attempt to determine content-type from cached content if possible, otherwise default
      if type(cached_content) == "string" and (cached_content:sub(1,1) == "{" or cached_content:sub(1,1) == "[") then
          kong.response.set_header("Content-Type", "application/json")
      else
          kong.response.set_header("Content-Type", "text/plain")
      end

      kong.log.debug("SemanticCacheLookup: Responding from cache for key: ", cache_key, " with status: ", conf.cache_hit_status)
      return kong.response.exit(conf.cache_hit_status, cached_content)
    else
      kong.response.set_header(conf.cache_hit_header_name, "HIT")
    end
  else
    kong.log.debug("SemanticCacheLookup: Cache MISS for key: ", cache_key, ". Error: ", err or "not found")
    kong.response.set_header(conf.cache_hit_header_name, "MISS")
  end
end

return SemanticCacheLookupHandler
