# KeyValueMapOperations Kong Plugin

## Purpose

The `KeyValueMapOperations` plugin for Kong Gateway allows you to perform `get`, `put`, and `delete` operations on Kong's shared dictionaries. This mirrors the functionality of Apigee's `KeyValueMapOperations` (KVM) policy, providing a flexible way to store, retrieve, and manage persistent key-value data across your API proxy flow.

This plugin is ideal for managing dynamic configurations, feature flags, or caching small pieces of data.

## Abilities and Features

*   **Flexible KVM Operations**: Supports `get` (retrieve), `put` (store/update), and `delete` (remove) operations.
*   **Named Shared Dictionaries**: Operates on a specific Kong shared dictionary, which must be configured in your Nginx environment.
*   **Dynamic Key Retrieval**: The key for the KVM operation can be extracted from various sources:
    *   **`header`**: A specific request header.
    *   **`query`**: A specific query parameter.
    *   **`body`**: A field within a JSON request body.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
    *   **`literal`**: A directly configured string.
*   **Dynamic Value Retrieval (for `put`)**: The value to be stored can also be extracted from the same flexible sources.
*   **Flexible Output Destination (for `get`)**: Retrieved values can be placed into:
    *   **`header`**: A specified request/response header.
    *   **`query`**: A specified query parameter.
    *   **`body`**: A field within a JSON request/response body (or replaces the entire body).
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
*   **Time-To-Live (TTL)**: For `put` operations, optionally specify a time-to-live in seconds, after which the entry will expire.
*   **Robust Error Handling**: Configurable `on_error_status` and `on_error_body` to return to the client if an operation fails. Option to `on_error_continue` processing even if an operation fails.

<h2>Important Note</h2>

This plugin relies on Kong's shared dictionaries, which are backed by Nginx's `lua_shared_dict` directive. You *must* configure the shared dictionary by adding a line like `lua_shared_dict <kvm_name> <size>;` to your Kong's Nginx configuration (e.g., in `nginx-kong.conf` or `kong.conf` under `nginx_http_`). For example: `lua_shared_dict my_config_kvm 10m;`

<h2>Use Cases</h2>

*   **Dynamic Configuration**: Store and retrieve application-specific settings, API endpoint URLs, or environment variables.
*   **Feature Flags**: Implement dynamic feature toggles that can be managed centrally.
*   **Lightweight Caching**: Cache frequently accessed data for short periods, reducing backend load and improving response times.
*   **Custom Rate Limiting**: Store and manage custom counters or states for rate limiting or quota enforcement logic.
*   **Cross-Request Data Sharing**: Share small pieces of data between requests if the `kvm_name` is scoped globally.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`kvm_name`**: (string, required) The name of the Kong shared dictionary (e.g., `my_config_kvm`) that this plugin will operate on. This name must match a `lua_shared_dict` configured in your Nginx.
*   **`operation_type`**: (string, required, enum: `get`, `put`, `delete`) The Key-Value Map operation to perform.
*   **`key_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`, `literal`) Specifies where to get the key for the KVM operation from.
*   **`key_source_name`**: (string, required) The name of the header/query parameter, the JSON path for a `body` source, the key in `kong.ctx.shared`, or the literal value itself if `key_source_type` is `literal`.
*   **`value_source_type`**: (string, conditional) Required for `put` operation. Specifies where to get the value to put into the KVM.
*   **`value_source_name`**: (string, conditional) Required for `put` operation. The name of the header/query parameter, the JSON path for a `body` source, the key in `kong.ctx.shared`, or the literal value itself if `value_source_type` is `literal`.
*   **`output_destination_type`**: (string, conditional) Required for `get` operation. Specifies where to place the retrieved value.
*   **`output_destination_name`**: (string, conditional) Required for `get` operation. The name of the header/query parameter, the JSON path for a `body` destination, or the key in `kong.ctx.shared` where the retrieved value will be stored.
*   **`ttl`**: (number, optional, min: `0`, max: `31536000`) For `put` operations, the time-to-live for the entry in seconds. If `0`, the entry does not expire. Defaults to no expiry if not set.
*   **`on_error_status`**: (number, default: `500`, between: `400` and `599`) The HTTP status code to return to the client if the KVM operation fails.
*   **`on_error_body`**: (string, default: "Key-Value Map operation failed.") The response body to return to the client if the KVM operation fails.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if the KVM operation fails. If `false`, the request will be terminated.

<h3>Example Nginx Configuration</h3>

Add this line to your `nginx-kong.conf` (or equivalent) in the `http` block:
```nginx
lua_shared_dict my_config_kvm 10m; # 10MB shared dictionary
```

<h3>Example Plugin Configuration (via Admin API)</h3>

**Enable on a Service to retrieve a configuration value:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=key-value-map-operations" \
    --data "config.kvm_name=my_config_kvm" \
    --data "config.operation_type=get" \
    --data "config.key_source_type=literal" \
    --data "config.key_source_name=api_version" \
    --data "config.output_destination_type=shared_context" \
    --data "config.output_destination_name=current_api_version" \
    --data "config.on_error_continue=true"
```

**Enable on a Route to put a value based on a query parameter with a TTL:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=key-value-map-operations" \
    --data "config.kvm_name=user_sessions" \
    --data "config.operation_type=put" \
    --data "config.key_source_type=header" \
    --data "config.key_source_name=X-User-ID" \
    --data "config.value_source_type=query" \
    --data "config.value_source_name=session_data" \
    --data "config.ttl=3600" # 1 hour expiry
```

**Enable globally to delete a key:**

```bash
curl -X POST http://localhost:8001/plugins \
    --data "name=key-value-map-operations" \
    --data "config.kvm_name=my_config_kvm" \
    --data "config.operation_type=delete" \
    --data "config.key_source_type=literal" \
    --data "config.key_source_name=stale_flag"
```
