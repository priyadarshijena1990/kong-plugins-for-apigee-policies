# Kong Plugin: Generate JWS

This plugin generates a signed JSON Web Signature (JWS) and places it in the request or context. It is designed to mimic the functionality of Apigee's `GenerateJWS` policy.

The plugin performs the signing operation locally and efficiently within Kong, using the `lua-resty-jwt` library.

## Dependencies

*   `lua-resty-jwt`

This dependency is managed by the included `generate-jws-0.1.0-1.rockspec` file. To install the plugin and its dependencies, you can use LuaRocks from within the plugin's directory:

```sh
luarocks make
```

## How it Works

The plugin can run in the `access` phase to generate a JWS that can be sent to the upstream service. It sources a payload, a private key (or secret), and header parameters from its configuration, signs the JWS, and then places the resulting token in a configured location (header, query parameter, body, or the shared context).

The payload is expected to be a JSON object. If the source (e.g., from a context variable) provides a JSON string, the plugin will decode it.

## Configuration

*   **`payload_source_type`**: (string, required) Where to get the payload content.
*   **`payload_source_name`**: (string, conditional) The name of the source (header, query param, context key, etc.).
*   **`private_key_source_type`**: (string, required) Where to get the private key or secret.
*   **`private_key_source_name`**: (string, conditional) The name of the context key if using `shared_context`.
*   **`private_key_literal`**: (string, conditional) The literal key/secret string if using `literal`.
*   **`algorithm`**: (string, required) The signing algorithm (e.g., `RS256`, `HS256`).
*   **`jws_header_parameters`**: (map, optional) Custom JWS header parameters (e.g., `kid`).
*   **`output_destination_type`**: (string, required) Where to place the generated JWS.
*   **`output_destination_name`**: (string, required) The name of the destination (header name, context key, etc.).
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, continue processing even if JWS generation fails.

### Example: Generate a JWS for an Upstream Service

This example generates a JWS and adds it to a request header before it is proxied to the upstream.

```yaml
plugins:
- name: generate-jws
  config:
    payload_source_type: shared_context
    payload_source_name: payload_for_jws # Assume a prior plugin created this table
    private_key_source_type: literal
    private_key_literal: "my-super-secret-for-hs256"
    algorithm: HS256
    jws_header_parameters:
      kid: "service-key-1"
    output_destination_type: header
    output_destination_name: "X-Service-JWS"
```

In this scenario:
1.  The plugin retrieves a Lua table from `kong.ctx.shared.payload_for_jws`.
2.  It signs this payload using the provided HS256 secret.
3.  It adds `alg: "HS256"` and `kid: "service-key-1"` to the JWS header.
4.  The final JWS string is placed in the `X-Service-JWS` request header, which is then sent to the upstream service.
