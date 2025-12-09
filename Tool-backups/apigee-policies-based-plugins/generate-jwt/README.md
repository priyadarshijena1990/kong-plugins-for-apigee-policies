# Kong Plugin: Generate JWT

This plugin generates a signed JSON Web Token (JWT) and places it in the request or context. It is designed to mimic the functionality of Apigee's `GenerateJWT` policy, offering fine-grained control over the token's claims.

The plugin performs the signing operation locally and efficiently within Kong, using the `lua-resty-jwt` library.

## Dependencies

*   `lua-resty-jwt`

This dependency is managed by the included `generate-jwt-0.1.0-1.rockspec` file. To install the plugin and its dependencies, you can use LuaRocks from within the plugin's directory:

```sh
luarocks make
```

## How it Works

The plugin can run in the `access` phase to generate a JWT that can be sent to the upstream service. It assembles a JWT payload by sourcing standard and custom claims from its configuration, signs the token with a configured key, and then places the resulting token in a specified location (header, query parameter, body, or the shared context).

## Configuration

The plugin has a rich set of configuration options for sourcing keys and claims.

### Key & Algorithm
*   **`algorithm`**: (string, required) The signing algorithm (e.g., `RS256`, `HS256`).
*   **`secret_source_type` / `secret_source_name` / `secret_literal`**: Specifies the source for the secret key when using an `HS` algorithm.
*   **`private_key_source_type` / `private_key_source_name` / `private_key_literal`**: Specifies the source for the private key when using an `RS` or `ES` algorithm.

### Standard Claims
*   **`subject_source_type` / `subject_source_name`**: Source for the `sub` claim.
*   **`issuer_source_type` / `issuer_source_name`**: Source for the `iss` claim.
*   **`audience_source_type` / `audience_source_name`**: Source for the `aud` claim.
*   **`expires_in_seconds`**: (number) If provided, sets the `exp` and `iat` claims.

### Custom Claims & Headers
*   **`jws_header_parameters`**: (map, optional) Custom JWS header parameters (e.g., `kid`).
*   **`additional_claims`**: (array of records) A list of additional custom claims to include in the payload. Each record specifies the `claim_name` and its source (`claim_value_source_type`, `claim_value_source_name`).

### Output
*   **`output_destination_type`**: (string, required) Where to place the generated JWT.
*   **`output_destination_name`**: (string, required) The name of the destination (header name, context key, etc.).

### Error Handling
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, continue processing even if JWT generation fails.

*(Each `*_source_type` can be one of `header`, `query`, `body`, `shared_context`, or `literal`)*

### Example: Generate a JWT for an Upstream Service

This example generates a JWT with standard and custom claims and adds it to a request header.

```yaml
plugins:
- name: generate-jwt
  config:
    algorithm: HS256
    secret_source_type: literal
    secret_literal: "my-super-secret"
    subject_source_type: literal
    subject_source_name: "user-123"
    issuer_source_type: literal
    issuer_source_name: "my-kong-gateway"
    expires_in_seconds: 3600 # 1 hour
    additional_claims:
    - claim_name: "user_role"
      claim_value_source_type: "header"
      claim_value_source_name: "X-User-Role"
    output_destination_type: header
    output_destination_name: "X-Upstream-JWT"
```
