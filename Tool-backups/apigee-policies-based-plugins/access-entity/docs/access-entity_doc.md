# AccessEntity Kong Plugin

## Purpose

The `AccessEntity` plugin for Kong Gateway allows you to extract specific attributes from the currently authenticated `consumer` or `credential` object and make them available as variables in `kong.ctx.shared`. This mimics the functionality of Apigee's `AccessEntity` policy, providing a flexible way to retrieve and utilize metadata associated with your API consumers or their authentication credentials.

This plugin is designed to operate on entities already identified by preceding authentication plugins, enriching the request context with valuable identity information.

## Abilities and Features

*   **Targeted Entity Extraction**: Extracts attributes from either the authenticated `consumer` object or its associated `credential` object.
*   **Configurable Attribute Mapping**: Define which `source_field` (e.g., `username`, `custom_id`, `client_id`, `name`, custom metadata) to extract from the entity.
*   **Shared Context Integration**: Stores the extracted values in `kong.ctx.shared` under configurable `output_key`s, making them accessible to other plugins, custom Lua logic, or `lua_conditions` throughout the request lifecycle.
*   **Default Value Support**: Provides an optional `default_value` to use if a specified `source_field` is not found on the entity, ensuring robustness in your configurations.

<h2>Important Note</h2>

This plugin operates on the `consumer` or `credential` object that has been identified and authenticated by a *preceding authentication plugin* (e.g., `key-auth`, `jwt`, `oauth2`). If no consumer or credential is authenticated by the time this plugin executes, it will log a warning and skip attribute extraction. It does not perform entity lookups from Kong's database if no entity is currently authenticated.

<h2>Use Cases</h2>

*   **Custom Authorization**: Leverage extracted attributes like `user_role`, `tier`, `group_id`, or `custom_flags` (stored as consumer metadata) to implement fine-grained access control.
*   **Logging and Analytics**: Enrich API access logs with detailed consumer or credential metadata for better insights and auditing.
*   **Dynamic Configuration**: Use entity attributes to dynamically configure the behavior of other plugins, upstream requests, or routing decisions.
*   **Data Enrichment**: Add consumer/credential-specific data to the request context before forwarding to upstream services (e.g., via a `Request Transformer` plugin).
*   **Tenant/Client-Specific Logic**: Drive tenant-specific or client-specific processing based on an attribute of the authenticated entity.

## Configuration

The plugin supports the following configuration parameters:

*   **`entity_type`**: (string, required, enum: `consumer`, `credential`) Specifies whether to extract attributes from the authenticated `consumer` object or the `credential` object.
*   **`extract_attributes`**: (array of records, required) A list of attributes to extract from the chosen entity. Each record has:
    *   **`source_field`**: (string, required) The exact field name on the `consumer` or `credential` object from which to extract the value (e.g., `username`, `custom_id`, `client_id`, `name`, or any custom field stored in the entity's metadata).
    *   **`output_key`**: (string, required) The key in `kong.ctx.shared` where the extracted attribute's value will be stored.
    *   **`default_value`**: (string, optional) A default string value to use if the `source_field` is not found on the entity.

### Example Configuration (via Admin API)

**Enable on a Service to extract consumer's username and custom tier:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=access-entity" \
    --data "config.entity_type=consumer" \
    --data "config.extract_attributes.1.source_field=username" \
    --data "config.extract_attributes.1.output_key=authenticated_username" \
    --data "config.extract_attributes.2.source_field=tier" \
    --data "config.extract_attributes.2.output_key=user_tier" \
    --data "config.extract_attributes.2.default_value=free"
```

**Enable on a Route to extract credential's client ID and a custom flag:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=access-entity" \
    --data "config.entity_type=credential" \
    --data "config.extract_attributes.1.source_field=client_id" \
    --data "config.extract_attributes.1.output_key=oauth_client_id" \
    --data "config.extract_attributes.2.source_field=is_privileged_app" \
    --data "config.extract_attributes.2.output_key=app_privileged_status" \
    --data "config.extract_attributes.2.default_value=false"
```

## Accessing Information

Extracted information is available in `kong.ctx.shared` using the `output_key`s defined in the `extract_attributes` configuration.

**Example (in a custom Lua plugin or `lua_condition`):**

```lua
local username = kong.ctx.shared.authenticated_username
local user_tier = kong.ctx.shared.user_tier

if user_tier == "premium" then
    kong.log.notice("Premium user '", username, "' accessing resource.")
    -- Apply premium-specific logic
else
    kong.log.notice("Standard user '", username, "' accessing resource.")
end
```
