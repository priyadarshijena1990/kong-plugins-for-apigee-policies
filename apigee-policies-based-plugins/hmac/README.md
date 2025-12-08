# Kong Plugin: HMAC

This plugin provides a utility for both generating and verifying a Hash-based Message Authentication Code (HMAC). It is designed to mimic the functionality of Apigee's `HMAC` policy.

This can be used to secure communications by ensuring message integrity and authenticity.

## How it Works

The plugin has two modes of operation, configured via the `mode` field:

### 1. Verify Mode (`mode: "verify"`)

In this mode, the plugin acts as a gatekeeper. It computes an HMAC signature based on components of the incoming request and compares it to a signature provided by the client in a header.
1.  It constructs a `string-to-sign` by concatenating configured request components (e.g., method, URI, headers, body parts) separated by newlines.
2.  It calculates the expected HMAC signature of this string using a configured secret key and algorithm.
3.  It compares the calculated signature to the one sent by the client in the `signature_header_name`.
4.  If the signatures do not match, the request is rejected with a `401` status code (configurable).

### 2. Generate Mode (`mode: "generate"`)

In this mode, the plugin acts as a signature generator.
1.  It constructs a `string-to-sign` in the same way as verify mode.
2.  It calculates the HMAC signature.
3.  It attaches the resulting signature to the request (in a header) or stores it in the shared context for other plugins to use before the request is sent to the upstream service.

## Configuration

*   **`mode`**: (string, required, default: `verify`) The mode of operation: `verify` or `generate`.
*   **`secret_source_type` / `secret_source_name` / `secret_literal`**: (required) Specifies the source for the shared secret key.
*   **`algorithm`**: (string, required) The HMAC algorithm to use (e.g., `HMAC-SHA256`).
*   **`string_to_sign_components`**: (array, required) An ordered list of components that will be concatenated with newlines to form the string-to-sign.
    *   **`component_type`**: (string, required) The type of component (`method`, `uri`, `header`, `query`, `body`, `literal`).
    *   **`component_name`**: (string, conditional) The name of the component (e.g., header name, query param name, literal string).

### Verification-Specific Configuration
*   **`signature_header_name`**: (string, required for verify mode) The header containing the client-provided HMAC signature.
*   **`signature_prefix`**: (string, optional) A prefix to strip from the signature header (e.g., `HMAC `).
*   **`on_verification_failure_*`**: Configure the response if verification fails.

### Generation-Specific Configuration
*   **`output_destination_type`**: (string, required for generate mode) Where to place the generated HMAC (`header` or `shared_context`).
*   **`output_destination_name`**: (string, required for generate mode) The name of the header or context key.

---

### Example 1: Verifying an Incoming Request

```yaml
plugins:
- name: hmac
  config:
    mode: verify
    secret_source_type: literal
    secret_literal: "my-secret-key"
    algorithm: HMAC-SHA256
    signature_header_name: X-Signature
    string_to_sign_components:
    - component_type: method
    - component_type: uri
    - component_type: header
      component_name: "X-Request-Timestamp"
    - component_type: body
```

### Example 2: Generating a Signature for an Upstream Service

```yaml
plugins:
- name: hmac
  config:
    mode: generate
    secret_source_type: shared_context
    secret_source_name: "upstream_hmac_secret"
    algorithm: HMAC-SHA512
    string_to_sign_components:
    - component_type: body
    output_destination_type: header
    output_destination_name: X-Upstream-Signature
```
