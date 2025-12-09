# RevokeOAuthV2 Kong Plugin

## Purpose

The `RevokeOAuthV2` plugin for Kong Gateway enables the revocation of OAuth 2.0 access and/or refresh tokens. This is a critical security mechanism that allows applications to invalidate tokens when a user logs out, changes their password, or when a token is compromised, thereby terminating active sessions and preventing unauthorized access.

The plugin intercepts a client request, extracts a token, and makes an outbound call to a configurable OAuth 2.0 token revocation endpoint. It then responds to the client based on the success or failure of the revocation attempt.

## Abilities and Features

*   **Token Extraction**: Retrieves the OAuth 2.0 token to be revoked from various sources within the incoming request:
    *   **`header`**: A specific request header (e.g., `Authorization` header for Bearer tokens).
    *   **`query`**: A specific query parameter.
    *   **`body`**: A field within a JSON request body (supports simple dot-notation paths).
    *   **`shared_context`**: A specified key in `kong.ctx.shared` where a token might have been stored by a previous plugin.
*   **Configurable Revocation Endpoint**: Targets any OAuth 2.0 compliant token `revocation_endpoint`.
*   **Client Authentication**: Supports sending `client_id` and `client_secret` to the revocation endpoint, either via HTTP Basic Authentication or as form parameters.
*   **Token Type Hint**: Optionally includes a `token_type_hint` (`access_token` or `refresh_token`) to inform the revocation endpoint about the type of token being revoked.
*   **Customizable Responses**: Provides configurable HTTP status codes and bodies for both successful token revocation and failures.

<h2>Use Cases</h2>

*   **Secure User Logout**: Integrate with application logout processes to immediately invalidate user sessions, preventing token reuse.
*   **Compromised Token Handling**: Implement procedures to revoke tokens that are suspected to be compromised, enhancing the overall security posture.
*   **Password Change Invalidation**: Automatically revoke all active tokens when a user changes their password, forcing re-authentication.
*   **Fine-Grained Session Control**: Enhance session management capabilities by providing a direct mechanism to terminate specific tokens.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`revocation_endpoint`**: (string, required) The full URL of the OAuth 2.0 provider's token revocation endpoint.
*   **`client_id`**: (string, required) The client ID used for authenticating the revocation request with the OAuth provider.
*   **`client_secret`**: (string, optional) The client secret used for authenticating the revocation request. If both `client_id` and `client_secret` are provided, HTTP Basic Authentication will be used. Otherwise, `client_id` (and `client_secret` if present) will be sent as form parameters.
*   **`token_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`) Specifies where to extract the token to be revoked from.
*   **`token_source_name`**: (string, required) The name of the header or query parameter, a dot-notation JSON path for a `body` source (e.g., `token.value`), or the key for `shared_context`. For `Authorization: Bearer <token>`, provide the header name (e.g., `Authorization`), and the plugin will automatically extract the token.
*   **`token_type_hint`**: (string, optional, enum: `access_token`, `refresh_token`) A hint to the authorization server about the type of the token submitted for revocation.
*   **`on_error_status`**: (number, default: `500`, between: `400` and `599`) The HTTP status code to return to the client if the token revocation call to the OAuth provider fails or returns an error.
*   **`on_error_body`**: (string, default: "Token revocation failed.") The response body to return to the client if the token revocation fails.
*   **`on_success_status`**: (number, default: `200`, between: `200` and `299`) The HTTP status code to return to the client if the token revocation call to the OAuth provider is successful.
*   **`on_success_body`**: (string, default: "Token revoked successfully.") The response body to return to the client if the token revocation is successful.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Route for revoking access tokens from `Authorization` header:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=revoke-oauth-v2" \
    --data "config.revocation_endpoint=https://auth.example.com/oauth2/revoke" \
    --data "config.client_id=my_client_id" \
    --data "config.client_secret=my_client_secret" \
    --data "config.token_source_type=header" \
    --data "config.token_source_name=Authorization" \
    --data "config.token_type_hint=access_token" \
    --data "config.on_success_status=200" \
    --data "config.on_success_body=Access token revoked."
```

**Enable on a Service for revoking refresh tokens from a query parameter:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=revoke-oauth-v2" \
    --data "config.revocation_endpoint=https://auth.example.com/oauth2/revoke" \
    --data "config.client_id=another_client" \
    --data "config.token_source_type=query" \
    --data "config.token_source_name=refresh_token" \
    --data "config.token_type_hint=refresh_token" \
    --data "config.on_error_status=401" \
    --data "config.on_error_body=Invalid refresh token."
```
