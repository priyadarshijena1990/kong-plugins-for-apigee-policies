# ReadPropertySet Kong Plugin

## Purpose

The `ReadPropertySet` plugin for Kong Gateway allows you to define a set of key-value properties and make them accessible as flow variables within `kong.ctx.shared`. This mimics the functionality of Apigee's `ReadPropertySet` policy, providing a mechanism to store and retrieve configurations, feature flags, or other dynamic data directly within your Kong proxy.

This enables you to manage application-specific settings or credentials without hardcoding them into your Lua plugins, enhancing flexibility and maintainability.

## Abilities and Features

*   **Inline PropertySet Definition**: Define a map of key-value pairs directly in the plugin configuration, acting as a "PropertySet".
*   **Flexible Variable Assignment**: Properties are exposed in `kong.ctx.shared` in two configurable ways:
    *   **Map Assignment**: The entire map of properties can be assigned to a single specified key in `kong.ctx.shared`.
    *   **Individual Assignment**: Each property can be assigned to its own key in `kong.ctx.shared`, prefixed by the `property_set_name` (e.g., `MyConfig.api_key`).
*   **Early Availability**: Properties are made available in the `access` phase, allowing subsequent plugins or custom logic to utilize them throughout the request lifecycle.

<h2>Use Cases</h2>

*   **Configuration Management**: Store and access environment-specific API keys, base URLs for internal services, feature flags, or other application settings.
*   **Dynamic Routing/Transformation**: Use configured properties to drive conditional routing decisions, modify request/response payloads, or select different upstream services.
*   **External Service Integration Settings**: Store parameters required for interacting with external services (e.g., API endpoint suffixes, client IDs, non-sensitive tokens).
*   **Centralized Settings**: Provide a centralized, version-controlled place for managing various application settings directly within your Kong configuration.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`property_set_name`**: (string, required) A logical name for this set of properties. This name is used as a prefix for individually assigned properties in `kong.ctx.shared` if `assign_to_shared_context_key` is not used.
*   **`properties`**: (map, required) A dictionary of key-value pairs. These are the properties that will be exposed. Values can be strings, numbers, booleans, or even nested tables (though direct Apigee policy typically assumes flat key-value pairs).
*   **`assign_to_shared_context_key`**: (string, optional) If specified, the entire `properties` map will be assigned to this key in `kong.ctx.shared`. If omitted, each key-value pair from `properties` will be assigned individually to `kong.ctx.shared[property_set_name .. "." .. key]`.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service, assigning the entire PropertySet to a single shared context key:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=read-property-set" \
    --data "config.property_set_name=MyGlobalConfig" \
    --data "config.properties.api_key=your_api_key_123" \
    --data "config.properties.service_url=https://backend.example.com" \
    --data "config.assign_to_shared_context_key=global_config_map"
```
*Access in Lua*: `local api_key = kong.ctx.shared.global_config_map.api_key`

**Enable on a Route, assigning individual properties with a prefix:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=read-property-set" \
    --data "config.property_set_name=FeatureFlags" \
    --data "config.properties.feature_x_enabled=true" \
    --data "config.properties.variant=A"
```
*Access in Lua*: `local feature_x = kong.ctx.shared["FeatureFlags.feature_x_enabled"]`

<h2>Accessing Properties</h2>

Properties assigned by this plugin are available in `kong.ctx.shared`.

**Example (in a custom Lua plugin's `access` phase):**

```lua
-- If using assign_to_shared_context_key="global_config_map"
local global_config = kong.ctx.shared.global_config_map
if global_config then
    kong.log.notice("API Key: ", global_config.api_key)
    kong.log.notice("Service URL: ", global_config.service_url)
end

-- If assigning individual properties (e.g., property_set_name="FeatureFlags")
local feature_x_enabled = kong.ctx.shared["FeatureFlags.feature_x_enabled"]
local variant = kong.ctx.shared["FeatureFlags.variant"]
if feature_x_enabled == "true" then -- Note: values are stored as strings
    kong.log.notice("Feature X is enabled with variant: ", variant)
end
```
