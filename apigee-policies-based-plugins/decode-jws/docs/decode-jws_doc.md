# DecodeJWS Kong Plugin

## Purpose

The `DecodeJWS` plugin for Kong Gateway is designed to decode a JSON Web Signature (JWS) and verify its cryptographic signature. This mirrors the functionality of Apigee's `DecodeJWS` policy, allowing you to ensure the integrity and authenticity of data or assertions passed via JWS.

**Important**: Due to the cryptographic complexities and the need for robust, battle-tested libraries, this plugin relies on an *external service* to perform the actual JWS decoding and signature verification. The plugin extracts the JWS and the public key, sends them to this external service, and then processes the service's response to extract claims.

## Abilities and Features

*   **JWS String Retrieval**: Extracts the JWS string from various sources within the incoming request:
    *   **`header`**: A specific request header (e.g., `Authorization` for `Bearer` JWS).
    *   **`query`**: A specific query parameter.
    *   **`body`**: A field within a JSON request body.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
*   **Public Key Provisioning**: Provides the public key or certificate required for signature verification from either:
    *   **`literal`**: A directly configured string.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
*   **External Verification**: Makes an HTTP call to a configurable `jws_decode_service_url` which handles the secure decoding and signature validation.
*   **Claim Extraction**: Extracts specified claims (e.g., `iss`, `aud`, `sub`, custom claims) from the verified JWS payload (as returned by the external service) and stores their values in `kong.ctx.shared` under configurable keys.
*   **Robust Error Handling**:
    *   Configurable `on_error_status` and `on_error_body` to return to the client if JWS processing fails.
    *   Option to `on_error_continue` processing even if decoding or verification fails.

<h2>Use Cases</h2>

*   **API Security**: Verify the authenticity and integrity of request parameters, payloads, or authentication tokens signed with JWS.
*   **Custom Authorization**: Extract roles, permissions, user IDs, or other authorization claims from a JWS for fine-grained access control logic.
*   **Inter-service Communication**: Validate JWS-signed messages exchanged between microservices to ensure data hasn't been tampered with and comes from a trusted source.
*   **Data Integrity**: Ensure the integrity of any data transferred via JWS.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`jws_decode_service_url`**: (string, required) The full URL of the external service endpoint that will perform the JWS decoding and signature verification. This service should accept a JWS string and a public key, and return the decoded claims (including header and payload) and verification status.
*   **`jws_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`) Specifies where to extract the JWS string from in the incoming request.
*   **`jws_source_name`**: (string, required) The name of the header or query parameter, the JSON path for a `body` source (e.g., `token.value`), or the key in `kong.ctx.shared` that holds the JWS string. For `Authorization: Bearer <JWS>`, provide the header name (`Authorization`), and the plugin will automatically extract the JWS part.
*   **`public_key_source_type`**: (string, required, enum: `literal`, `shared_context`) Specifies where to get the public key/certificate for JWS signature verification.
*   **`public_key_source_name`**: (string, conditional) Required if `public_key_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the public key/certificate string.
*   **`public_key_literal`**: (string, conditional) Required if `public_key_source_type` is `literal`. The actual public key/certificate string to use for verification.
*   **`claims_to_extract`**: (array of records, optional) A list of JWS claims to extract from the verified JWS payload and store in `kong.ctx.shared`. Each record has:
    *   **`claim_name`**: (string, required) The name of the claim (e.g., `iss`, `aud`, `sub`, `exp`, or a custom claim like `user_id`) to extract from the JWS payload.
    *   **`output_key`**: (string, required) The key in `kong.ctx.shared` where the extracted claim value will be stored.
*   **`on_error_status`**: (number, default: `500`, between: `400` and `599`) The HTTP status code to return to the client if JWS decoding or verification fails.
*   **`on_error_body`**: (string, default: "JWS decoding or verification failed.") The response body to return to the client if JWS processing fails.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if JWS decoding or verification fails. If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to decode a JWS from an Authorization header, using a literal public key:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=decode-jws" \
    --data "config.jws_decode_service_url=http://jws-verifier.example.com/decode" \
    --data "config.jws_source_type=header" \
    --data "config.jws_source_name=Authorization" \
    --data "config.public_key_source_type=literal" \
    --data "config.public_key_literal=-----BEGIN PUBLIC KEY-----MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..." \
    --data "config.claims_to_extract.1.claim_name=sub" \
    --data "config.claims_to_extract.1.output_key=jws_subject" \
    --data "config.claims_to_extract.2.claim_name=iss" \
    --data "config.claims_to_extract.2.output_key=jws_issuer" \
    --data "config.on_error_continue=false" \
    --data "config.on_error_status=401" \
    --data "config.on_error_body=Invalid JWS token."
```

**Enable on a Route to decode a JWS from a shared context variable, using a public key also from shared context:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=decode-jws" \
    --data "config.jws_decode_service_url=http://jws-verifier.example.com/decode" \
    --data "config.jws_source_type=shared_context" \
    --data "config.jws_source_name=message_jws" \
    --data "config.public_key_source_type=shared_context" \
    --data "config.public_key_source_name=service_public_key" \
    --data "config.claims_to_extract.1.claim_name=transaction_id" \
    --data "config.claims_to_extract.1.output_key=tx_id" \
    --data "config.on_error_continue=true"
```