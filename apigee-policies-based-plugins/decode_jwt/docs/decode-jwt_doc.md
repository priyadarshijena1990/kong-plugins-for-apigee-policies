# DecodeJWT Kong Plugin

## Purpose

The `DecodeJWT` plugin for Kong Gateway is designed to decode a JSON Web Token (JWT) and extract its header and payload claims, making them available as variables in `kong.ctx.shared`. This directly mirrors the functionality of Apigee's `DecodeJWT` policy.

This plugin allows you to inspect the contents of a JWT for various purposes like routing, logging, or custom logic, without necessarily performing signature verification.

## Abilities and Features

*   **JWT String Retrieval**: Extracts the JWT string from various sources within the incoming request:
    *   **`header`**: A specific request header (e.g., `Authorization` for `Bearer` JWT).
    *   **`query`**: A specific query parameter.
    *   **`body`**: A field within a JSON request body.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
*   **JWT Parsing**: Splits the JWT into its header, payload, and signature components.
*   **Base64url & JSON Decoding**: Base64url decodes and JSON parses the header and payload sections into Lua tables.
*   **Claim Extraction**: Extracts specified claims (e.g., `iss`, `aud`, `sub`, `exp`, custom claims) from the decoded JWT payload and stores their values in `kong.ctx.shared` under configurable keys.
*   **Full Header/Payload Storage**: Optionally stores the entire decoded JWT header and/or the entire decoded payload (all claims) as Lua tables in `kong.ctx.shared` for more comprehensive access.
*   **Robust Error Handling**:
    *   Configurable `on_error_status` and `on_error_body` to return to the client if JWT parsing/decoding fails.
    *   Option to `on_error_continue` processing even if decoding fails.

<h2>Important Note</h2>

This plugin *only decodes* the JWT. It *does NOT perform signature verification* or validate claims (e.g., checking expiry time, audience, issuer). For cryptographic validation and claim verification, you would typically use Kong's built-in `jwt` authentication plugin or a dedicated JWT verification service/plugin.

<h2>Use Cases</h2>

*   **Accessing Claims for Logic**: Extract claims like `sub` (subject), `iss` (issuer), `scope`, or custom claims to use in routing decisions, conditional logic, or data enrichment.
*   **Logging and Auditing**: Log the decoded contents of JWTs for auditing, debugging, or analytical purposes.
*   **Pre-verification Inspection**: Quickly inspect specific claims in a JWT before a more resource-intensive signature verification step, or when you implicitly trust the issuer.
*   **Token Introspection**: Provide basic token introspection capabilities by exposing decoded claims.

## Configuration

The plugin supports the following configuration parameters:

*   **`jwt_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`) Specifies where to extract the JWT string from in the incoming request.
*   **`jwt_source_name`**: (string, required) The name of the header or query parameter, the JSON path for a `body` source (e.g., `token.jwt`), or the key in `kong.ctx.shared` that holds the JWT string. For `Authorization: Bearer <JWT>`, provide the header name (`Authorization`), and the plugin will automatically extract the JWT part.
*   **`claims_to_extract`**: (array of records, optional) A list of JWT claims to extract from the decoded payload and store in `kong.ctx.shared`. Each record has:
    *   **`claim_name`**: (string, required) The name of the claim (e.g., `iss`, `aud`, `sub`, `exp`, `user_id`) to extract from the JWT payload.
    *   **`output_key`**: (string, required) The key in `kong.ctx.shared` where the extracted claim value will be stored.
*   **`store_all_claims_in_shared_context_key`**: (string, optional) If set, the entire decoded JWT payload (as a Lua table) will be stored in `kong.ctx.shared` under this key.
*   **`store_header_to_shared_context_key`**: (string, optional) If set, the entire decoded JWT header (as a Lua table) will be stored in `kong.ctx.shared` under this key.
*   **`on_error_status`**: (number, default: `400`, between: `400` and `599`) The HTTP status code to return to the client if JWT decoding fails.
*   **`on_error_body`**: (string, default: "JWT decoding failed.") The response body to return to the client if JWT decoding fails.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if JWT decoding fails. If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to decode a JWT from an Authorization header, extracting common claims:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=decode-jwt" \
    --data "config.jwt_source_type=header" \
    --data "config.jwt_source_name=Authorization" \
    --data "config.claims_to_extract.1.claim_name=sub" \
    --data "config.claims_to_extract.1.output_key=jwt_subject" \
    --data "config.claims_to_extract.2.claim_name=iss" \
    --data "config.claims_to_extract.2.output_key=jwt_issuer" \
    --data "config.store_all_claims_in_shared_context_key=jwt_payload_all" \
    --data "config.on_error_status=401" \
    --data "config.on_error_body=Invalid or malformed JWT."
```

**Enable on a Route to decode a JWT from a query parameter and store the full header:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=decode-jwt" \
    --data "config.jwt_source_type=query" \
    --data "config.jwt_source_name=token" \
    --data "config.store_header_to_shared_context_key=jwt_header_data" \
    --data "config.claims_to_extract.1.claim_name=custom_id" \
    --data "config.claims_to_extract.1.output_key=user_custom_id" \
    --data "config.on_error_continue=true"
```

## Accessing Information

Decoded claims and (optionally) the full header and payload are available in `kong.ctx.shared` under the configured `output_key`s.

**Example (in a custom Lua plugin or `lua_condition`):**

```lua
local subject = kong.ctx.shared.jwt_subject
local issuer = kong.ctx.shared.jwt_issuer
local all_claims = kong.ctx.shared.jwt_payload_all

if subject and issuer == "my_auth_provider" then
    kong.log.notice("JWT from trusted issuer. Subject: ", subject)
    -- Access other claims like all_claims.exp or all_claims.user_role
end
```
