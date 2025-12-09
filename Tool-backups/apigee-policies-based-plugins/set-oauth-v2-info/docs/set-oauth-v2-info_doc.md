# SetOAuthV2Info Kong Plugin

## Purpose

The `SetOAuthV2Info` plugin for Kong Gateway is designed to extract and expose critical OAuth 2.0 related information into the request context (`kong.ctx.shared`). This mirrors the functionality of Apigee's `SetOAuthV2Info` policy, providing a structured way to access details about the authenticated consumer and client associated with an OAuth 2.0 access token.

This plugin assumes that an authentication plugin (e.g., Kong's OAuth 2.0 plugin, JWT plugin, or any custom authentication) has already successfully identified and authenticated a consumer and potentially a credential.

## Abilities and Features

*   **Standard OAuth Information Extraction**: Automatically extracts common OAuth 2.0 related information such as:
    *   `consumer_id`: The ID of the authenticated consumer.
    *   `consumer_username`: The username or custom ID of the authenticated consumer.
    *   `client_id`: The ID of the client application.
    *   `application_name`: The name of the application associated with the client.
*   **Custom Attribute Extraction**: Allows administrators to configure a list of custom attributes to be extracted from the authenticated consumer or credential objects.
*   **Context Sharing**: All extracted information is stored in `kong.ctx.shared.oauth_v2_info`, making it easily accessible to other plugins, custom Lua logic, or transformations later in the request lifecycle.

## Use Cases

*   **Fine-Grained Access Control**: Use the extracted `client_id`, `consumer_id`, or custom attributes in policy decisions (e.g., in a custom Lua plugin or an Open Policy Agent integration) to enforce more granular access rules.
*   **Dynamic Routing**: Route requests to different upstream services or versions based on the client application or consumer's specific attributes.
*   **Rate Limiting and Quota Enforcement**: Integrate with other plugins to apply rate limits or quotas based on specific `client_id`s or consumer groups identified by custom attributes.
*   **Enhanced Logging and Analytics**: Include OAuth 2.0 context in logs or send to analytics platforms for better insights into API usage by authenticated clients and consumers.
*   **API Transformation**: Modify request or response payloads based on the identity or attributes of the calling client/consumer.

## Configuration

The plugin supports the following configuration parameter:

*   **`custom_attributes`**: (optional, array of strings) A list of string names representing custom attributes that should be extracted from the authenticated consumer or credential object. If an attribute with the specified name exists, its value will be added to the `oauth_v2_info` table.

### Example Configuration (via Admin API)

**Enable globally:**

```bash
curl -X POST http://localhost:8001/plugins \
    --data "name=set-oauth-v2-info" \
    --data "config.custom_attributes=department,tier"
```

**Enable on a specific Service:**

```bash
curl -X POST http://localhost:8001/services/{service}/plugins \
    --data "name=set-oauth-v2-info" \
    --data "config.custom_attributes=subscription_level"
```

**Enable on a specific Route:**

```bash
curl -X POST http://localhost:8001/routes/{route}/plugins \
    --data "name=set-oauth-v2-info"
```

## Accessing Information

Once the `SetOAuthV2Info` plugin has executed (in the `access` phase), the extracted OAuth 2.0 information can be accessed in subsequent phases and plugins via `kong.ctx.shared.oauth_v2_info`.

**Example (in a custom Lua plugin's `access` or `header_filter` phase):**

```lua
local oauth_info = kong.ctx.shared.oauth_v2_info

if oauth_info then
    kong.log.notice("Consumer ID: ", oauth_info.consumer_id)
    kong.log.notice("Client ID: ", oauth_info.client_id)

    if oauth_info.subscription_level then
        kong.log.notice("Subscription Level: ", oauth_info.subscription_level)
    end

    -- You can then use this information for logic
    if oauth_info.client_id == "my_premium_client" then
        -- Apply premium logic
    end
end
```