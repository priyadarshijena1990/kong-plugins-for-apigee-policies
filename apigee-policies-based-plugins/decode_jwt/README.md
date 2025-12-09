# Kong Plugin: Decode JWT

This plugin decodes a JSON Web Token (JWT) to extract its header and payload claims without verifying the signature. It is designed to mimic the functionality of Apigee's `DecodeJWT` policy.

This is useful for inspecting the content of a JWT (e.g., reading the `iss` or `kid` from the header) before another plugin performs signature verification.

**Warning**: This plugin **DOES NOT** verify the JWT's signature. Do not rely on it alone for authentication or authorization. It should always be followed by a verification step (e.g., using the `verify-jws` plugin or Kong's built-in `jwt` plugin).

## Dependencies

*   `lua-resty-jwt`

This dependency is managed by the included `decode-jwt-0.1.0-1.rockspec` file. To install the plugin and its dependencies, you can use LuaRocks:

```sh
luarocks make
```

## How it Works

The plugin retrieves a JWT string from the request and uses the `lua-resty-jwt` library to safely parse it into its header and payload components.

It can then store the entire header, the entire payload, or specific individual claims into `kong.ctx.shared` for use by other plugins.

## Configuration

*   **`jwt_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`) Specifies where to extract the JWT string from.
*   **`jwt_source_name`**: (string, required) The name of the header, query parameter, JSON path for a `body` source, or the key in `kong.ctx.shared`. For `Authorization: Bearer <JWT>`, provide the header name (`Authorization`).
*   **`claims_to_extract`**: (array of records, optional) A list of specific claims to extract from the decoded payload and store in `kong.ctx.shared`.
    *   **`claim_name`**: (string, required) The name of the claim (e.g., `iss`, `sub`).
    *   **`output_key`**: (string, required) The key in `kong.ctx.shared` where the value will be stored.
*   **`store_all_claims_in_shared_context_key`**: (string, optional) If set, the entire decoded payload (as a Lua table) will be stored in `kong.ctx.shared` under this key.
*   **`store_header_to_shared_context_key`**: (string, optional) If set, the entire decoded header (as a Lua table) will be stored in `kong.ctx.shared` under this key.
*   **`on_error_status`**: (number, default: `400`) The HTTP status code to return if decoding fails.
*   **`on_error_body`**: (string, default: "JWT decoding failed.") The response body to return on failure.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, continue processing even if decoding fails.

### Example Configuration:

```yaml
plugins:
- name: decode-jwt
  config:
    jwt_source_type: header
    jwt_source_name: Authorization
    store_header_to_shared_context_key: jwt_header
    claims_to_extract:
      - claim_name: iss
        output_key: jwt_issuer
```

This example decodes a JWT from the `Authorization` header, stores the entire header table in `kong.ctx.shared.jwt_header`, and extracts the `iss` claim into `kong.ctx.shared.jwt_issuer`.