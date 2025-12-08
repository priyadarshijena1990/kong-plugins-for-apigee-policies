# ResetQuota Kong Plugin

## Purpose

The `ResetQuota` plugin for Kong Gateway allows you to programmatically reset the counter for a specific instance of Kong's built-in `rate-limiting` plugin. This mirrors the functionality of Apigee's `ResetQuota` policy, providing a way to immediately clear accumulated quota usage for testing, administrative tasks, or automated quota management.

This plugin operates by making an authenticated `DELETE` request to Kong's Admin API to trigger the reset.

## Abilities and Features

*   **Targeted Quota Reset**: Resets the counter for a specific `rate-limiting` plugin instance, identified by its Kong Admin API ID.
*   **Scoped Reset**: Can reset a global counter or a counter specifically scoped by a `consumer`, `service`, or `route` (depending on how the target `rate-limiting` plugin is configured).
*   **Dynamic Scope ID Retrieval**: If resetting a scoped counter, the identifier for that scope (e.g., a `consumer_id`, `service_id`, or `route_id`) can be extracted from various request sources or provided as a literal.
*   **Admin API Authentication**: Supports authenticating the `DELETE` request to Kong's Admin API using an API key.
*   **Robust Error Handling**:
    *   Configurable `on_error_status` and `on_error_body` to return to the client if the reset operation fails.
    *   Option to `on_error_continue` processing even if the reset operation fails.

<h2>Important Note</h2>

*   This plugin makes an outbound HTTP `DELETE` call to Kong's Admin API. Therefore, the `admin_api_url` must be accessible from the Kong worker nodes and properly secured.
*   The `rate_limiting_plugin_id` is the unique ID assigned to your specific `rate-limiting` plugin instance when it's configured in Kong.
*   Ensure that the `scope_type` and the `scope_id` you provide match how the target `rate-limiting` plugin is actually configured (e.g., if the `rate-limiting` plugin uses `limit_by=consumer`, you should provide `scope_type=consumer` and the appropriate consumer ID).

<h2>Use Cases</h2>

*   **Administrative Resets**: Allow API administrators to manually reset a client's quota usage, for example, to grant immediate access after a subscription upgrade.
*   **Automated Quota Management**: Integrate with external billing or CRM systems to automatically reset quotas based on business events (e.g., end of billing cycle, payment confirmation).
*   **Testing and Debugging**: Facilitate easier testing of rate-limiting configurations during development by quickly resetting counters.
*   **Error Recovery**: Reset quotas in specific error scenarios that might have incorrectly consumed quota units.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`admin_api_url`**: (string, required) The base URL of Kong's Admin API (e.g., `http://kong-admin:8001`).
*   **`admin_api_key`**: (string, optional) An API key (if configured for your Admin API) to authenticate the reset request. This will be sent as an `apikey` header.
*   **`rate_limiting_plugin_id`**: (string, required) The unique ID of the specific `rate-limiting` plugin instance whose quota counter is to be reset.
*   **`scope_type`**: (string, optional, enum: `consumer`, `service`, `route`) The type of entity the quota is scoped by. If omitted, the plugin will attempt to reset the global counter for the specified `rate-limiting_plugin_id`.
*   **`scope_id_source_type`**: (string, conditional) Required if `scope_type` is set. Specifies where to get the ID of the scoped entity.
*   **`scope_id_source_name`**: (string, conditional) Required if `scope_type` is set. The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal ID value itself if `scope_id_source_type` is 'literal'.
*   **`on_error_status`**: (number, default: `500`, between: `400` and `599`) The HTTP status code to return to the client if the quota reset operation fails.
*   **`on_error_body`**: (string, default: `"Quota reset failed."`) The response body to return to the client if the quota reset operation fails.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if the quota reset operation fails. If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Route to reset a specific consumer's quota for a plugin instance:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=reset-quota" \
    --data "config.admin_api_url=http://kong-admin:8001" \
    --data "config.admin_api_key=your_admin_api_key" \
    --data "config.rate_limiting_plugin_id=a1b2c3d4-e5f6-7890-1234-567890abcdef" \
    --data "config.scope_type=consumer" \
    --data "config.scope_id_source_type=header" \
    --data "config.scope_id_source_name=X-Consumer-ID" \
    --data "config.on_error_continue=false" \
    --data "config.on_error_status=400" \
    --data "config.on_error_body=Could not reset consumer quota."
```

**Enable globally to reset a global quota for a specific plugin instance (e.g., triggered by an admin webhook):**

```bash
curl -X POST http://localhost:8001/plugins \
    --data "name=reset-quota" \
    --data "config.admin_api_url=http://kong-admin:8001" \
    --data "config.rate_limiting_plugin_id=f0e9d8c7-b6a5-4321-fedc-ba9876543210" \
    --data "config.on_error_continue=true"
```
