# Kong Plugin: Delete OAuth V2 Info

This plugin deletes an OAuth 2.0 access token from Kong's database, effectively revoking it. It is designed to mimic the functionality of Apigee's `DeleteOAuthV2Info` policy.

This provides a way to create a token revocation endpoint. When this plugin is attached to a route, any request to that route will trigger the plugin to find and delete the specified token.

## How it Works

The plugin retrieves an OAuth 2.0 access token string from the request (e.g., from a header or the request body). It then uses this token string to find and delete the corresponding entry in Kong's `oauth2_tokens` database table.

This action is immediate and permanent for the specified token.

## Configuration

*   **`token_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`) Specifies where to extract the OAuth 2.0 access token string from.
*   **`token_source_name`**: (string, required) The name of the header, query parameter, JSON path for a `body` source, or the key in `kong.ctx.shared` that holds the token string.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if the token cannot be found or a database error occurs. If `false`, the request may be terminated with a `400` or `500` status code.

### Example Configuration:

This example configures the plugin on a route, perhaps `/revoke`, to delete a token passed in the request body.

**1. Add the plugin to a route:**

```yaml
plugins:
- name: delete-oauth-v2-info
  config:
    token_source_type: body
    token_source_name: token_to_revoke
```

**2. Send a request to the route to revoke a token:**

A `POST` request to `/revoke` with the following body would trigger the plugin to delete the token `abc123xyz`.

```json
{
  "token_to_revoke": "abc123xyz"
}
```

The plugin will then attempt to delete the token `abc123xyz` from Kong's database. The response to the client will depend on what upstream service, if any, is configured for the route.
