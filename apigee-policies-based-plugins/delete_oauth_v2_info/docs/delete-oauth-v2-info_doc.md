# DeleteOAuthV2Info Kong Plugin

## Purpose

The `DeleteOAuthV2Info` plugin for Kong Gateway provides a mechanism to explicitly clear specific OAuth 2.0 related information from `kong.ctx.shared`. This mimics a conceptual "delete" operation for OAuth 2.0 flow variables in Apigee, allowing you to manage the lifecycle of sensitive or temporary OAuth 2.0 related data within your API proxy's context.

This plugin is useful for cleanup, resetting context, or ensuring that specific OAuth 2.0 data is removed from `kong.ctx.shared` once it's no longer needed.

## Abilities and Features

*   **Targeted Deletion**: Configure a specific list of keys in `kong.ctx.shared` (`keys_to_delete`) whose values will be set to `nil`.
*   **Context Control**: Provides explicit control over the OAuth 2.0 related data present in the shared context during the request lifecycle.
*   **Early Execution**: Operates in the `access` phase, allowing for timely cleanup or resetting of context before the request proceeds further.

<h2>Important Note</h2>

This plugin *only* clears data from Kong's internal `kong.ctx.shared` store. It *does not* interact with any OAuth 2.0 authorization server to revoke actual access or refresh tokens. For token revocation, the `RevokeOAuthV2` plugin should be used.

<h2>Use Cases</h2>

*   **Context Cleanup**: Remove sensitive or temporary OAuth 2.0 attributes from `kong.ctx.shared` after they have been used by other plugins, preventing their accidental exposure or use downstream.
*   **Conditional Context Reset**: In scenarios where a request might be re-processed or undergo different authentication paths, this plugin can be used to clear previous OAuth 2.0 context.
*   **Ensuring Freshness**: Guarantee that a subsequent plugin attempting to read OAuth 2.0 information from a specific key will not receive stale data, as the key would have been explicitly cleared.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`keys_to_delete`**: (array of strings, required) A list of exact keys in `kong.ctx.shared` that you want to set to `nil`. These keys would typically correspond to values previously populated by plugins like `GetOAuthV2Info` or `SetOAuthV2Info`.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to clear specific OAuth 2.0 related data after processing:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=delete-oauth-v2-info" \
    --data "config.keys_to_delete=oauth_client_id" \
    --data "config.keys_to_delete=oauth_scopes" \
    --data "config.keys_to_delete=oauth_app_name"
```

**Enable on a Route to clear all custom OAuth 2.0 attributes:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=delete-oauth-v2-info" \
    --data "config.keys_to_delete=client_tier" \
    --data "config.keys_to_delete=client_department"
```
