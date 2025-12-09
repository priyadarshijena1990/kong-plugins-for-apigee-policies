# GetOAuthV2Info Kong Plugin

## Purpose

The `GetOAuthV2Info` plugin for Kong Gateway is designed to extract key information from an authenticated OAuth 2.0 context and make it available as variables in `kong.ctx.shared`. This mirrors the functionality of Apigee's `GetOAuthV2Info` policy, allowing subsequent plugins or custom logic to leverage details about the authenticated client application, end-user, and granted scopes.

This plugin assumes that an authentication plugin (like Kong's OAuth 2.0 Authentication plugin) has already successfully processed an OAuth 2.0 token and populated the `kong.ctx` with authentication details.

## Abilities and Features

*   **Extracts Standard OAuth 2.0 Details**: Automatically retrieves common OAuth 2.0 related information such as:
    *   **Client ID**: The identifier of the authenticated client application.
    *   **Application Name**: The name of the client application (from the credential).
    *   **End-User Identifier**: An identifier for the authenticated end-user (from the consumer).
    *   **Scopes**: The OAuth scopes associated with the access token.
*   **Custom Attribute Extraction**: Configurable mappings to extract additional `custom_attributes` from the authenticated `consumer` or `credential` objects (as populated by other Kong authentication plugins).
*   **Shared Context Integration**: All extracted information is stored in `kong.ctx.shared` under configurable keys, making it easily accessible to other plugins, custom Lua logic, or `lua_conditions` throughout the request lifecycle.

<h2>Important Note</h2>

This plugin *does not* perform OAuth 2.0 token verification itself. It relies on the presence of authentication information already populated in `kong.ctx` by other authentication plugins (e.g., Kong's OAuth 2.0 Authentication plugin, JWT plugin, or custom authentication solutions).

<h2>Use Cases</h2>

*   **Fine-grained Authorization**: Use extracted `scopes` or `custom_attributes` to make authorization decisions for specific API resources or actions.
*   **Quota and Rate Limiting**: Apply dynamic quota or rate limiting policies based on the `client_id`, `app_name`, or `end_user`.
*   **Auditing and Logging**: Enrich API access logs with detailed OAuth 2.0 context, including client, application, and user information.
*   **Custom Business Logic**: Implement application-specific logic that adapts its behavior based on the identity or attributes of the authenticated client application or end-user.
*   **Data Enrichment**: Add OAuth 2.0 context to upstream requests (e.g., via a `Request Transformer` plugin).

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`extract_client_id_to_shared_context_key`**: (string, optional) If set, the authenticated client ID will be stored in `kong.ctx.shared` under this key.
*   **`extract_app_name_to_shared_context_key`**: (string, optional) If set, the authenticated application name (from `credential.name`) will be stored in `kong.ctx.shared` under this key.
*   **`extract_end_user_to_shared_context_key`**: (string, optional) If set, an identifier for the authenticated end-user (from `consumer.username` or `consumer.custom_id`) will be stored in `kong.ctx.shared` under this key.
*   **`extract_scopes_to_shared_context_key`**: (string, optional) If set, the OAuth scopes associated with the token will be stored in `kong.ctx.shared` under this key.
*   **`extract_custom_attributes`**: (array of records, optional) A list of custom attributes to extract. Each record has:
    *   **`source_field`**: (string, required) The name of the field to extract from the authenticated `consumer` or `credential` object (e.g., `custom_attribute_1`, `some_metadata_field`).
    *   **`output_key`**: (string, required) The key in `kong.ctx.shared` where the extracted custom attribute will be stored.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to extract standard OAuth 2.0 details:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=get-oauth-v2-info" \
    --data "config.extract_client_id_to_shared_context_key=oauth_client_id" \
    --data "config.extract_app_name_to_shared_context_key=oauth_app_name" \
    --data "config.extract_end_user_to_shared_context_key=oauth_end_user" \
    --data "config.extract_scopes_to_shared_context_key=oauth_scopes"
```

**Enable on a Route to extract custom attributes from the consumer object:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=get-oauth-v2-info" \
    --data "config.extract_client_id_to_shared_context_key=current_client_id" \
    --data "config.extract_custom_attributes.1.source_field=tier" \
    --data "config.extract_custom_attributes.1.output_key=client_tier" \
    --data "config.extract_custom_attributes.2.source_field=department" \
    --data "config.custom_attributes.2.output_key=client_department"
```

<h2>Accessing Information</h2>

Extracted information is available in `kong.ctx.shared` using the `output_key`s defined in the configuration.

**Example (in a custom Lua plugin or `lua_condition`):**

```lua
local client_id = kong.ctx.shared.oauth_client_id
local app_name = kong.ctx.shared.oauth_app_name
local scopes = kong.ctx.shared.oauth_scopes

if client_id and scopes and string.find(scopes, "admin") then
    kong.log.notice("Admin client '", client_id, "' access detected for app '", app_name, "'")
    -- Perform admin-specific actions
end
```