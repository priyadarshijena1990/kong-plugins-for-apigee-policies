# HMAC Kong Plugin

## Purpose

The `HMAC` plugin for Kong Gateway is designed to verify the integrity and authenticity of incoming API requests by validating their Hash-based Message Authentication Code (HMAC) signatures. This mirrors the functionality of Apigee's HMAC policy, providing a robust mechanism to ensure that requests have not been tampered with and originate from a trusted source.

This plugin calculates an HMAC signature based on specific components of the incoming request and a shared secret, then compares it against a signature provided by the client.

## Abilities and Features

*   **Signature Extraction**: Extracts the client-provided HMAC signature from a configurable HTTP `signature_header_name`, optionally stripping a `signature_prefix`.
*   **Shared Secret Provisioning**: Retrieves the shared secret key required for HMAC calculation from either:
    *   **`literal`**: A directly configured string.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
*   **Algorithm Support**: Supports common HMAC algorithms: `HMAC-SHA1`, `HMAC-SHA256`, and `HMAC-SHA512`.
*   **Configurable String-to-Sign**: Dynamically constructs the "string-to-sign" by concatenating configurable components of the incoming request in a specified order. Components can be:
    *   **`method`**: The HTTP method (e.g., `GET`, `POST`).
    *   **`uri`**: The request URI.
    *   **`header`**: A specific request header's value.
    *   **`query`**: A specific query parameter's value.
    *   **`body`**: The raw request body or a JSON field from it.
    *   **`literal`**: A static string.
*   **HMAC Calculation & Comparison**: Calculates the HMAC signature using the specified algorithm and string-to-sign, then compares it with the client-provided signature.
*   **Robust Error Handling**:
    *   Configurable `on_verification_failure_status` and `on_verification_failure_body` to return to the client if verification fails.
    *   Option to `on_verification_failure_continue` processing even if verification fails.

<h2>Important Note</h2>

For successful HMAC verification, it is absolutely critical that the "string-to-sign" and the HMAC calculation process (algorithm, secret, encoding) are identical on both the client side (where the signature is generated) and the gateway side (where it is verified). Any discrepancy will lead to verification failure.

<h2>Use Cases</h2>

*   **Request Integrity**: Guarantee that API requests have not been altered in transit by an unauthorized party.
*   **Client Authentication**: Authenticate API clients who possess a shared secret, often as a primary or secondary authentication mechanism.
   `Non-Repudiation`: Provide a degree of non-repudiation, confirming the sender's identity.
*   **Inter-service Security**: Secure communication between microservices within an architecture by validating signed internal requests.
*   **Webhook Security**: Verify the authenticity of incoming webhooks.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`signature_header_name`**: (string, required) The name of the HTTP header where the client-provided HMAC signature is expected (e.g., `Authorization`, `X-Client-Signature`).
*   **`signature_prefix`**: (string, optional, default: `""`) A string prefix to strip from the value of the `signature_header_name` before comparison (e.g., "HMAC ").
*   **`secret_source_type`**: (string, required, enum: `literal`, `shared_context`) Specifies where to get the shared secret key for HMAC calculation.
*   **`secret_source_name`**: (string, conditional) Required if `secret_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the shared secret string.
*   **`secret_literal`**: (string, conditional) Required if `secret_source_type` is `literal`. The actual shared secret string.
*   **`algorithm`**: (string, required, enum: `HMAC-SHA1`, `HMAC-SHA256`, `HMAC-SHA512`) The HMAC algorithm to use for signature calculation.
*   **`string_to_sign_components`**: (array of records, required) A list defining the components that form the 'string-to-sign' in the specified order. These components are concatenated with newline characters (`\n`) between them. Each record has:
    *   **`component_type`**: (string, required, enum: `method`, `uri`, `header`, `query`, `body`, `literal`) The type of component to include.
    *   **`component_name`**: (string, conditional)
        *   Required for `header`: The name of the header (e.g., `Content-MD5`).
        *   Required for `query`: The name of the query parameter (e.g., `timestamp`).
        *   Required for `body`: A dot-notation JSON path (e.g., `data.field`) or `.` for the entire body.
        *   Required for `literal`: The literal string value.
        *   Not required for `method`, `uri`.
*   **`on_verification_failure_status`**: (number, default: `401`, between: `400` and `599`) The HTTP status code to return if HMAC verification fails.
*   **`on_verification_failure_body`**: (string, default: `"HMAC verification failed."`) The response body to return if HMAC verification fails.
*   **`on_verification_failure_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if HMAC verification fails. If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to verify HMAC-SHA256 signature from `Authorization` header:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=hmac" \
    --data "config.signature_header_name=Authorization" \
    --data "config.signature_prefix=HMAC-SHA256 " \
    --data "config.secret_source_type=shared_context" \
    --data "config.secret_source_name=client_secret_for_hmac" \
    --data "config.algorithm=HMAC-SHA256" \
    --data "config.string_to_sign_components.1.component_type=method" \
    --data "config.string_to_sign_components.2.component_type=uri" \
    --data "config.string_to_sign_components.3.component_type=header" \
    --data "config.string_to_sign_components.3.component_name=Content-MD5" \
    --data "config.string_to_sign_components.4.component_type=header" \
    --data "config.string_to_sign_components.4.component_name=Date" \
    --data "config.on_verification_failure_status=401" \
    --data "config.on_verification_failure_body=Invalid HMAC signature."
```

**Enable on a Route to verify a simple HMAC-SHA1 signature from a custom header, using a literal secret:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=hmac" \
    --data "config.signature_header_name=X-My-Signature" \
    --data "config.secret_source_type=literal" \
    --data "config.secret_literal=my_super_secret_key" \
    --data "config.algorithm=HMAC-SHA1" \
    --data "config.string_to_sign_components.1.component_type=query" \
    --data "config.string_to_sign_components.1.component_name=timestamp" \
    --data "config.string_to_sign_components.2.component_type=literal" \
    --data "config.string_to_sign_components.2.component_name=api_v1" \
    --data "config.on_verification_failure_continue=false"
```
