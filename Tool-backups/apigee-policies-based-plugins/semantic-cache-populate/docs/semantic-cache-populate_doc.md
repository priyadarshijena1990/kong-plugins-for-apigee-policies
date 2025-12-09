# SemanticCachePopulate Kong Plugin

## Purpose

The `SemanticCachePopulate` plugin for Kong Gateway allows you to dynamically populate Kong's in-memory cache with data based on semantic rules, mirroring the functionality of Apigee's `SemanticCachePopulate` policy. This enables API proxies to store responses or other critical data for later retrieval, significantly reducing backend load and improving API response times.

The plugin generates a unique cache key from configurable components of the current request and stores content (either the upstream response body or data from `kong.ctx.shared`) for a specified Time-To-Live (TTL).

## Abilities and Features

*   **Dynamic Cache Key Generation**: Construct unique cache keys using a configurable `cache_key_prefix` and multiple `cache_key_fragments`. Fragments can be derived from:
    *   Request URI (`request.uri`)
    *   Request method (`request.method`)
    *   Request headers (`request.headers.Accept`)
    *   Request query parameters (`request.query_param.id`)
    *   Values stored in `kong.ctx.shared` (`shared_context.my_data`)
    *   Literal strings.
*   **Flexible Cache Content Source**: Specify whether the content to be cached should be:
    *   **`response_body`**: The raw body of the upstream service's response.
    *   **`shared_context`**: The value associated with a specified key in `kong.ctx.shared`. Supports automatic JSON serialization for Lua table values.
*   **Configurable Time-To-Live (TTL)**: Set the expiration time for cached entries in seconds.
*   **In-Memory Caching**: Utilizes Kong's powerful `kong.cache` mechanism, which can be backed by various storage solutions (e.g., Redis) if configured in your Kong environment.

<h2>Use Cases</h2>

*   **API Response Caching**: Store full API responses to frequently accessed endpoints, reducing latency and backend server load.
*   **Data Aggregation Caching**: Cache the results of complex data aggregations or external service callouts (e.g., from a `ServiceCallout` plugin) that are stored in `kong.ctx.shared`.
*   **Session State Caching**: Cache session-specific data that is expensive to generate or retrieve.
*   **Rate Limit/Quota Data**: Store custom rate limit or quota counters that might be managed by external systems and refreshed periodically.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`cache_key_prefix`**: (string, optional, default: `""`) A static string to prepend to the generated cache key. Useful for namespacing cache entries.
*   **`cache_key_fragments`**: (array of strings, optional, default: `{}`) A list of references to values that will be concatenated (separated by colons) to form the unique cache key. Supported reference formats:
    *   `request.uri`: The full request URI.
    *   `request.method`: The HTTP method of the request.
    *   `request.headers.<header_name>`: The value of a specific request header (e.g., `request.headers.Accept`).
    *   `request.query_param.<param_name>`: The value of a specific query parameter (e.g., `request.query_param.id`).
    *   `shared_context.<key_name>`: The value from `kong.ctx.shared` associated with `<key_name>`. If the value is a Lua table, it will be JSON-encoded.
    *   Any other string: Treated as a literal fragment.
*   **`cache_ttl`**: (number, required, min: `1`, max: `31536000`) The Time-To-Live for the cached entry, in seconds.
*   **`source`**: (string, required, enum: `response_body`, `shared_context`) Specifies where the content to be cached should be retrieved from.
*   **`shared_context_key`**: (string, conditional, required if `source` is `shared_context`) The key in `kong.ctx.shared` whose value will be cached.

<h3>Example Configuration (via Admin API)</h3>

**Enable globally to cache a service's response based on URI and Accept header:**

```bash
curl -X POST http://localhost:8001/plugins \
    --data "name=semantic-cache-populate" \
    --data "config.cache_key_prefix=api_response" \
    --data "config.cache_key_fragments=request.uri" \
    --data "config.cache_key_fragments=request.headers.Accept" \
    --data "config.cache_ttl=60" \
    --data "config.source=response_body"
```

**Enable on a Service to cache data from shared context, based on query param and a literal:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=semantic-cache-populate" \
    --data "config.cache_key_prefix=user_session" \
    --data "config.cache_key_fragments=request.query_param.user_id" \
    --data "config.cache_key_fragments=user_data_version_1" \
    --data "config.cache_ttl=3600" \
    --data "config.source=shared_context" \
    --data "config.shared_context_key=processed_user_data"
```

<h2>Relation to SemanticCacheLookup Plugin</h2>

This `SemanticCachePopulate` plugin is typically used in conjunction with a `SemanticCacheLookup` (or similar) plugin. The `SemanticCacheLookup` plugin would be placed earlier in the request flow (e.g., `access` phase) to attempt to retrieve a cached entry using a similarly constructed cache key. If a valid entry is found, the lookup plugin would serve the cached response directly, bypassing the upstream service. If not found, the request proceeds to the upstream, and this `SemanticCachePopulate` plugin would then cache the fresh response for future requests.
