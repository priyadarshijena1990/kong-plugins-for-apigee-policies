# SemanticCacheLookup Kong Plugin

## Purpose

The `SemanticCacheLookup` plugin for Kong Gateway allows you to dynamically retrieve data from Kong's in-memory cache based on semantic rules, mirroring the functionality of Apigee's `SemanticCacheLookup` policy. This plugin is typically placed early in the request lifecycle to check if a response can be served directly from the cache, thereby bypassing upstream services, reducing latency, and alleviating backend load.

## Abilities and Features

*   **Dynamic Cache Key Generation**: Constructs unique cache keys using a configurable `cache_key_prefix` and multiple `cache_key_fragments`. This key generation logic is consistent with the `SemanticCachePopulate` plugin, ensuring that lookup keys match population keys. Fragments can be derived from:
    *   Request URI (`request.uri`)
    *   Request method (`request.method`)
    *   Request headers (`request.headers.Accept`)
    *   Request query parameters (`request.query_param.id`)
    *   Values stored in `kong.ctx.shared` (`shared_context.my_data`)
    *   Literal strings.
*   **Cache Lookup**: Efficiently retrieves cached content using the generated key from Kong's in-memory cache.
*   **Flexible Cache Hit Handling**:
    *   **Respond Directly**: If `respond_from_cache_on_hit` is `true` (default), the plugin will immediately serve the cached content to the client, along with a configurable status code and headers, completely bypassing the upstream service.
    *   **Store in Shared Context**: If `assign_to_shared_context_key` is configured, the cached content will be stored in `kong.ctx.shared` for use by subsequent plugins, even if the plugin doesn't respond directly.
*   **Cache Status Header**: Sets a configurable header (default: `X-Cache-Status`) to indicate whether the response was a "HIT" or a "MISS".
*   **Cache Miss Handling**: If a cache miss occurs, the plugin allows the request to proceed normally to the upstream service, typically where a `SemanticCachePopulate` plugin would then cache the upstream's response.

<h2>Use Cases</h2>

*   **Accelerating API Responses**: Serve static or slowly changing API responses instantly from the cache, improving perceived performance for clients.
*   **Reducing Backend Load**: Minimize the number of requests reaching your backend services for commonly requested data.
*   **Conditional Processing**: Use the `X-Cache-Status` header or cached data in `kong.ctx.shared` in conjunction with other plugins for conditional routing or transformation logic.
*   **A/B Testing Cached vs. Fresh**: In advanced scenarios, the `X-Cache-Status` header can be used to analyze the impact of caching strategies.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`cache_key_prefix`**: (string, optional, default: `""`) A static string to prepend to the generated cache key. Must match the `SemanticCachePopulate` plugin's prefix for corresponding cache entries.
*   **`cache_key_fragments`**: (array of strings, optional, default: `{}`) A list of references to values that will be concatenated (separated by colons) to form the unique cache key. This must match the `SemanticCachePopulate` plugin's fragments. Supported reference formats:
    *   `request.uri`: The full request URI.
    *   `request.method`: The HTTP method of the request.
    *   `request.headers.<header_name>`: The value of a specific request header (e.g., `request.headers.Accept`).
    *   `request.query_param.<param_name>`: The value of a specific query parameter (e.g., `request.query_param.id`).
    *   `shared_context.<key_name>`: The value from `kong.ctx.shared` associated with `<key_name>`. If the value is a Lua table, it will be JSON-encoded (consistent with `SemanticCachePopulate`).
    *   Any other string: Treated as a literal fragment.
*   **`assign_to_shared_context_key`**: (string, optional) If configured, the cached content (on a cache hit) will be stored in `kong.ctx.shared` under this key. This allows other plugins to process the cached data even if `respond_from_cache_on_hit` is `false`.
*   **`respond_from_cache_on_hit`**: (boolean, default: `true`) If `true`, on a cache hit, the plugin will immediately send the cached content as the client response, bypassing the upstream service. If `false`, the cached content will only be stored in `kong.ctx.shared` (if `assign_to_shared_context_key` is set), and the request will proceed to the upstream.
*   **`cache_hit_status`**: (number, default: `200`, between: `200` and `599`) The HTTP status code to use when responding directly from the cache (only applicable if `respond_from_cache_on_hit` is `true`).
*   **`cache_hit_headers`**: (map, optional) A dictionary of additional headers to include in the response when serving from cache.
*   **`cache_hit_header_name`**: (string, default: `X-Cache-Status`) The name of the HTTP header to set on the response, indicating "HIT" or "MISS".

<h3>Example Configuration (via Admin API)</h3>

**Enable globally to look up responses cached by SemanticCachePopulate:**

```bash
curl -X POST http://localhost:8001/plugins \
    --data "name=semantic-cache-lookup" \
    --data "config.cache_key_prefix=api_response" \
    --data "config.cache_key_fragments=request.uri" \
    --data "config.cache_key_fragments=request.headers.Accept" \
    --data "config.respond_from_cache_on_hit=true" \
    --data "config.cache_hit_status=200" \
    --data "config.cache_hit_headers.Content-Type=application/json" \
    --data "config.cache_hit_header_name=X-My-Cache"
```

**Enable on a Service to store cached data in shared context for further processing:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=semantic-cache-lookup" \
    --data "config.cache_key_prefix=user_session" \
    --data "config.cache_key_fragments=request.query_param.user_id" \
    --data "config.assign_to_shared_context_key=cached_user_data" \
    --data "config.respond_from_cache_on_hit=false" \
    --data "config.cache_hit_header_name=X-Session-Cache"
```

<h2>Relation to SemanticCachePopulate Plugin</h2>

This `SemanticCacheLookup` plugin is designed to work in tandem with the `SemanticCachePopulate` plugin. For a complete caching strategy, you would typically configure `SemanticCacheLookup` early in the request flow (e.g., in the `access` phase) to check for a cached entry. If found, it serves the cached response directly. If not found (a cache miss), the request proceeds to the upstream, and then a `SemanticCachePopulate` plugin (configured with matching `cache_key_prefix` and `cache_key_fragments`) would be placed in the response flow (e.g., `body_filter` phase) to cache the upstream's response for subsequent requests.
