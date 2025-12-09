# Kong Plugin: Invalidate Cache

This plugin purges entries from Kong's cache. It is designed to mimic the functionality of Apigee's `InvalidateCache` policy.

This plugin works in conjunction with other caching plugins (like Apigee's `PopulateCache` or `ResponseCache` equivalents) that populate the cache. It allows for the explicit removal of cached entries before their natural expiry.

## How it Works

The plugin has two modes of operation, configured via the `purge_by_prefix` field:

### 1. Single Key Invalidation (`purge_by_prefix: false`)

This is the default mode. It constructs a highly specific cache key from a `cache_key_prefix` and a series of `cache_key_fragments`. It then deletes the single entry matching that exact key from the cache.

This is useful for targeted invalidation, such as when a specific resource is updated.

### 2. Bulk Prefix Invalidation (`purge_by_prefix: true`)

In this mode, the plugin purges all cache entries that start with the configured `cache_key_prefix`. This is a powerful feature for bulk invalidation, such as clearing all cached data related to a specific user or application when their profile changes.

**Important**: This mode directly accesses Kong's default shared memory cache (`kong_cache`) to retrieve the list of all keys. It will not work if your Kong data plane is configured to use a different cache backend for `kong.cache`.

## Configuration

*   **`purge_by_prefix`**: (boolean, default: `false`) If `true`, enables bulk invalidation mode.
*   **`cache_key_prefix`**: (string) A prefix for the cache key. In bulk mode, this is the prefix used for purging. In single key mode, it's prepended to the generated key.
*   **`cache_key_fragments`**: (array of strings) In single key mode, this is a list of request/context parts to build the cache key (e.g., `request.uri`, `shared_context.user_id`). Ignored in bulk mode.
*   **`continue_on_invalidation`**: (boolean, default: `true`) If `true`, the request continues after the invalidation attempt. If `false`, the plugin terminates the flow and returns a success or failure message.
*   **`on_invalidation_success_*`**: Configures the response if `continue_on_invalidation` is `false` and the operation succeeds.
*   **`on_invalidation_failure_*`**: Configures the response if `continue_on_invalidation` is `false` and the operation fails.

---

### Example 1: Invalidating a Specific API Response

Imagine a `PopulateCache` plugin is caching responses for `GET /users/{user_id}` with a cache key like `my-api:user-profile:{user_id}`. A `PUT` request to the same endpoint should invalidate this entry.

**Attach to the `PUT` route for `/users/{user_id}`:**
```yaml
plugins:
- name: invalidate-cache
  config:
    purge_by_prefix: false
    cache_key_prefix: "my-api:user-profile"
    cache_key_fragments:
    - "request.uri.segment[2]" # Assuming URI is /users/{user_id}
    continue_on_invalidation: true
```

### Example 2: Purging All of a User's Cached Data

Imagine multiple cache entries are prefixed with a user's ID (e.g., `user-123:profile`, `user-123:orders`). A `DELETE` request to `/users/123` could purge all of them.

**Attach to the `DELETE` route for `/users/{user_id}`:**
```yaml
plugins:
- name: invalidate-cache
  config:
    purge_by_prefix: true
    cache_key_prefix: "user-123" # This value would likely be set dynamically by a preceding plugin
    continue_on_invalidation: false
    on_invalidation_success_status: 204
```
