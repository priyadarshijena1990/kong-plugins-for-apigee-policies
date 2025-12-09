# Kong Plugin: Verify JWS

This plugin verifies a JSON Web Signature (JWS) and extracts its claims. It is designed to mimic the functionality of Apigee's `VerifyJWS` policy.

The plugin performs signature verification locally and efficiently within Kong, using the `lua-resty-jwt` library.

## Dependencies

*   `lua-resty-jwt`

This dependency is managed by the included `verify-jws-0.1.0-1.rockspec` file. To install the plugin and its dependencies, you can use LuaRocks:

```sh
luarocks make
```

## How it Works

The plugin retrieves a JWS from the request, verifies its signature using a configured public key or secret, and checks if the signing algorithm is in an allowed list.

If the JWS is valid, the plugin extracts specified claims from the payload and stores them in `kong.ctx.shared` for use by other plugins or upstream services.

If the JWS is invalid, the plugin will either terminate the request with a `401` status code or allow the request to proceed, based on the `on_error_continue` configuration.

## Configuration

The plugin supports the following configuration parameters:

*   **`jws_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`) Specifies where to extract the JWS string from.
*   **`jws_source_name`**: (string, required) The name of the header, query parameter, JSON path for a `body` source, or the key in `kong.ctx.shared`. For `Authorization: Bearer <JWS>`, provide the header name (`Authorization`).
*   **`public_key_source_type`**: (string, required, enum: `literal`, `shared_context`) Specifies where to get the public key (for RS/ES algorithms) or secret (for HS algorithms).
*   **`public_key_source_name`**: (string, conditional) Required if `public_key_source_type` is `shared_context`. The key in `kong.ctx.shared` that holds the key material.
*   **`public_key_literal`**: (string, conditional) Required if `public_key_source_type` is `literal`. The actual key material string.
*   **`allowed_algorithms`**: (array of strings, default: `["RS256"]`) A list of allowed signing algorithms (e.g., "RS256", "HS512") to prevent algorithm switching attacks.
*   **`claims_to_extract`**: (array of records, optional) A list of claims to extract from the verified payload and store in `kong.ctx.shared`.
    *   **`claim_name`**: (string, required) The name of the claim (e.g., `iss`, `sub`).
    *   **`output_key`**: (string, required) The key in `kong.ctx.shared` where the value will be stored.
*   **`on_error_status`**: (number, default: `401`) The HTTP status code to return on verification failure.
*   **`on_error_body`**: (string, default: "JWS verification failed.") The response body to return on failure.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, continue processing even if verification fails.

### Example Configuration:

```yaml
plugins:
- name: verify-jws
  config:
    jws_source_type: header
    jws_source_name: Authorization
    public_key_source_type: literal
    public_key_literal: |
      -----BEGIN PUBLIC KEY-----
      MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
      -----END PUBLIC KEY-----
    allowed_algorithms:
      - RS256
    claims_to_extract:
      - claim_name: sub
        output_key: consumer_id
      - claim_name: scope
        output_key: consumer_scope
```

This example verifies a JWS from the `Authorization` header using a literal public key, allows only the `RS256` algorithm, and extracts the `sub` and `scope` claims into the context.
