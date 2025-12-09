# GenerateJWS Kong Plugin

## Purpose

The `GenerateJWS` plugin for Kong Gateway allows you to generate a signed JSON Web Signature (JWS) during the API flow. This mirrors the functionality of Apigee's `GenerateJWS` policy, enabling you to create cryptographically signed data payloads for various security and data integrity purposes.

**Important**: Due to the cryptographic complexities and the need for robust, battle-tested libraries, this plugin relies on an *external service* to perform the actual JWS generation and signing. The plugin gathers the necessary components (payload, private key, algorithm, header parameters), sends them to this external service, and then processes the service's response to retrieve the signed JWS.

## Abilities and Features

*   **Payload Retrieval**: Extracts the content to be signed (the payload) from various sources:
    *   **`header`**: A specific request header.
    *   **`query`**: A specific query parameter.
    *   **`body`**: A field within a JSON request body.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
    *   **`literal`**: A directly configured string.
*   **Private Key Provisioning**: Provides the private key required for signing from either:
    *   **`literal`**: A directly configured string.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
*   **External Signing**: Makes an HTTP call to a configurable `jws_generate_service_url` which handles the secure JWS generation and signing process.
*   **Configurable Algorithm**: Specify the JWS signing `algorithm` (e.g., `HS256`, `RS256`, `ES256`).
*   **Custom JWS Header Parameters**: Allows adding custom `jws_header_parameters` (e.g., `kid` - Key ID, `typ` - Type).
*   **JWS Output Destination**: Stores the generated JWS string in a configurable destination:
    *   **`header`**: A specified request/response header.
    *   **`query`**: A specified query parameter.
    *   **`body`**: A field within a JSON request/response body (or replaces the entire body).
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
*   **Robust Error Handling**:
    *   Configurable `on_error_status` and `on_error_body` to return to the client if JWS generation fails.
    *   Option to `on_error_continue` processing even if generation fails.

<h2>Use Cases</h2>

*   **Secure Inter-service Communication**: Generate JWS-signed requests for authenticating and ensuring the integrity of calls to downstream microservices.
*   **Custom Authentication Tokens**: Create custom signed tokens for internal authentication or authorization mechanisms that can be verified by consuming services.
*   **Data Integrity Assurance**: Sign data payloads to guarantee that they have not been altered in transit and originated from a trusted source.
*   **API Gateway Security**: Implement advanced security patterns by issuing or forwarding JWS-signed assertions.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`jws_generate_service_url`**: (string, required) The full URL of the external service endpoint that will perform the JWS generation and signing. This service should accept a payload, private key, algorithm, and header parameters, and return the generated JWS string.
*   **`payload_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`, `literal`) Specifies where to extract the content that will be signed as the JWS payload.
*   **`payload_source_name`**: (string, required) The name of the header/query parameter, the JSON path for a `body` source (e.g., `data.message`), the key in `kong.ctx.shared`, or the literal value itself if `payload_source_type` is `literal`.
*   **`private_key_source_type`**: (string, required, enum: `literal`, `shared_context`) Specifies where to get the private key for JWS signing.
*   **`private_key_source_name`**: (string, conditional) Required if `private_key_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the private key string.
*   **`private_key_literal`**: (string, conditional) Required if `private_key_source_type` is `literal`. The actual private key string to use for signing.
*   **`algorithm`**: (string, required, enum: `HS256`, `RS256`, `ES256`) The JWS signing algorithm to use.
*   **`jws_header_parameters`**: (map, optional) A map of custom JWS header parameters (e.g., `{"kid": "my_key_id", "typ": "JWS"}`).
*   **`output_destination_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`) Specifies where to place the generated JWS string.
*   **`output_destination_name`**: (string, required) The name of the header or query parameter, the JSON path for a `body` destination, or the key in `kong.ctx.shared` where the JWS string will be stored.
*   **`on_error_status`**: (number, default: `500`, between: `400` and `599`) The HTTP status code to return to the client if JWS generation or signing fails.
*   **`on_error_body`**: (string, default: "JWS generation failed.") The response body to return to the client if JWS processing fails.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if JWS generation or signing fails. If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to sign a request body and place the JWS in an Authorization header, using a private key from shared context:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=generate-jws" \
    --data "config.jws_generate_service_url=http://jws-signer.example.com/generate" \
    --data "config.payload_source_type=body" \
    --data "config.payload_source_name=." \
    --data "config.private_key_source_type=shared_context" \
    --data "config.private_key_source_name=private_key_for-service" \
    --data "config.algorithm=RS256" \
    --data "config.jws_header_parameters.kid=my_service_key" \
    --data "config.output_destination_type=header" \
    --data "config.output_destination_name=Authorization" \
    --data "config.on_error_continue=false" \
    --data "config.on_error_status=500" \
    --data "config.on_error_body=Failed to generate secure token."
```

**Enable on a Route to sign a literal string and store the JWS in shared context:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=generate-jws" \
    --data "config.jws_generate_service_url=http://jws-signer.example.com/generate" \
    --data "config.payload_source_type=literal" \
    --data "config.payload_source_name=user:123:roles:admin" \
    --data "config.private_key_source_type=literal" \
    --data "config.private_key_literal=-----BEGIN PRIVATE KEY-----MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDEc..." \
    --data "config.algorithm=HS256" \
    --data "config.output_destination_type=shared_context" \
    --data "config.output_destination_name=internal_jws_assertion" \
    --data "config.on_error_continue=true"
```