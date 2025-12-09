# SAMLAssertion Kong Plugin

## Purpose

The `SAMLAssertion` plugin for Kong Gateway allows you to either generate a Security Assertion Markup Language (SAML) assertion or verify an incoming SAML assertion within your API flow. This mirrors the functionality of Apigee's `SAMLAssertion` policy, enabling integration with SAML-based identity providers for secure communication and federated identity management.

**Important**: Due to the significant complexity of SAML (involving XML parsing, digital signatures, encryption, and adherence to various schemas), this plugin relies on an *external service* to perform the actual SAML generation or verification. The plugin acts as a client to this dedicated SAML processing microservice.

## Abilities and Features

*   **Flexible Operation Type**: Configure the plugin to either `generate` a SAML assertion or `verify` an incoming one.
*   **Delegation to External Service**: All complex SAML logic is handled by a configurable `saml_service_url` (an external SAML processing microservice).
*   **Generate Operation**:
    *   Retrieves payload data (to be embedded in the assertion) and a private key for signing from various sources.
    *   Sends them to the external SAML service.
    *   Stores the generated SAML assertion XML string in a configurable destination (header, query, body, shared context).
*   **Verify Operation**:
    *   Retrieves the SAML assertion XML string to be verified and a public key/certificate for verification.
    *   Sends these to the external SAML service.
    *   If successfully verified, extracts specified SAML attributes and stores their values in `kong.ctx.shared` under configurable keys.
*   **Key Provisioning**: Signing/verification keys can be provided as `literal` strings or retrieved from `shared_context`.
*   **Robust Error Handling**:
    *   Configurable `on_error_status` and `on_error_body` to return to the client if the SAML operation fails.
    *   Option to `on_error_continue` processing even if a SAML operation fails.

<h2>Use Cases</h2>

*   **Single Sign-On (SSO)**: Integrate Kong with SAML-based identity providers (IdPs) or service providers (SPs) to enable secure SSO for your APIs.
*   **Federated Identity**: Consume SAML assertions from an IdP to establish user identity across different security domains.
*   **Secure API Communication**: Generate signed SAML assertions to authenticate and authorize requests to downstream services that expect SAML.
*   **Claim-Based Authorization**: Extract user attributes (claims) from verified SAML assertions to implement fine-grained authorization logic.

<h2>Configuration</h2>

The plugin supports the following configuration parameters, which vary depending on the `operation_type`:

*   **`saml_service_url`**: (string, required) The full URL of the external service endpoint that will perform the SAML assertion generation or verification.
*   **`operation_type`**: (string, required, enum: `generate`, `verify`) Specifies whether the plugin should generate a SAML assertion or verify an incoming one.

<h3>Configuration for `operation_type: generate`</h3>

*   **`saml_payload_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`, `literal`) Specifies where to get the data that will form the content of the SAML assertion payload.
*   **`saml_payload_source_name`**: (string, required) The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `saml_payload_source_type` is 'literal'.
*   **`signing_key_source_type`**: (string, required, enum: `literal`, `shared_context`) Specifies where to get the private key for signing the SAML assertion.
*   **`signing_key_source_name`**: (string, conditional) Required if `signing_key_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the private key string.
*   **`signing_key_literal`**: (string, conditional) Required if `signing_key_source_type` is `literal`. The actual private key string.
*   **`output_destination_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`) Specifies where to place the generated SAML assertion XML string.
*   **`output_destination_name`**: (string, required) The name of the header/query parameter, JSON path for `body`, or key in `kong.ctx.shared`.

<h3>Configuration for `operation_type: verify`</h3>

*   **`saml_assertion_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`) Specifies where to get the SAML assertion XML string to be verified.
*   **`saml_assertion_source_name`**: (string, required) The name of the header/query parameter, JSON path for `body`, or key in `kong.ctx.shared`.
*   **`verification_key_source_type`**: (string, required, enum: `literal`, `shared_context`) Specifies where to get the public key/certificate for verifying the SAML assertion.
*   **`verification_key_source_name`**: (string, conditional) Required if `verification_key_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the public key/certificate string.
*   **`verification_key_literal`**: (string, conditional) Required if `verification_key_source_type` is `literal`. The actual public key/certificate string.
*   **`extract_claims`**: (array of records, optional) A list of SAML attributes to extract from the verified assertion and store in `kong.ctx.shared`.
    *   **`attribute_name`**: (string, required) The name of the SAML attribute (e.g., `uid`, `emailaddress`, or `urn:oid:1.3.6.1.4.1.5923.1.1.1.6` for eduPersonPrincipalName).
    *   **`output_key`**: (string, required) The key in `kong.ctx.shared` where the extracted SAML attribute value will be stored.

<h3>Common Configuration</h3>

*   **`on_error_status`**: (number, default: `500`, between: `400` and `599`) The HTTP status code to return to the client if the SAML operation fails.
*   **`on_error_body`**: (string, default: "SAML operation failed.") The response body to return to the client if the SAML operation fails.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if the SAML operation fails. If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to generate a SAML assertion from a request body and put it in a header:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=saml-assertion" \
    --data "config.saml_service_url=http://saml-processor.example.com" \
    --data "config.operation_type=generate" \
    --data "config.saml_payload_source_type=body" \
    --data "config.saml_payload_source_name=." \
    --data "config.signing_key_source_type=shared_context" \
    --data "config.signing_key_source_name=service_private_key_pem" \
    --data "config.output_destination_type=header" \
    --data "config.output_destination_name=X-SAML-Assertion" \
    --data "config.on_error_status=500" \
    --data "config.on_error_body=Failed to generate SAML assertion."
```

**Enable on a Route to verify an incoming SAML assertion from a header and extract user attributes:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=saml-assertion" \
    --data "config.saml_service_url=http://saml-processor.example.com" \
    --data "config.operation_type=verify" \
    --data "config.saml_assertion_source_type=header" \
    --data "config.saml_assertion_source_name=Authorization" \
    --data "config.verification_key_source_type=literal" \
    --data "config.verification_key_literal=-----BEGIN CERTIFICATE-----MIIFijCCBHKgAwIBAgIQD..." \
    --data "config.extract_claims.1.attribute_name=emailaddress" \
    --data "config.extract_claims.1.output_key=saml_user_email" \
    --data "config.extract_claims.2.attribute_name=displayName" \
    --data "config.extract_claims.2.output_key=saml_display_name" \
    --data "config.on_error_continue=false" \
    --data "config.on_error_status=401" \
    --data "config.on_error_body=SAML assertion invalid or not verified."
```