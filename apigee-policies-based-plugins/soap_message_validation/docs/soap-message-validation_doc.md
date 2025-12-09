# SOAPMessageValidation Kong Plugin

## Purpose

The `SOAPMessageValidation` plugin for Kong Gateway allows you to validate SOAP messages (requests or responses) against their corresponding XML Schema Definitions (XSDs). This mirrors the functionality of Apigee's `SOAPMessageValidation` policy, ensuring that the structure and content of your SOAP messages conform to expected standards, thereby improving API reliability and security.

**Important**: Due to the complexity of XML Schema validation, this plugin relies on an *external service* to perform the actual validation. The plugin extracts the SOAP message and the XSD schema, sends them to this external service, and then processes the service's response to determine validation status.

## Abilities and Features

*   **Delegation to External Service**: All complex SOAP/XSD validation logic is handled by a configurable `soap_validation_service_url` (an external validation microservice).
*   **Flexible Message Source**: Retrieves the SOAP message (as an XML string) from various sources:
    *   **`request_body`**: The raw body of the client's incoming request.
    *   **`response_body`**: The raw body of the upstream service's response.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
*   **Flexible XSD Schema Source**: Retrieves the XSD schema definition from:
    *   **`literal`**: A directly configured XSD XML string.
    *   **`url`**: A URL from which the external service should fetch the XSD.
    *   **`shared_context`**: A specified key within `kong.ctx.shared` holding the XSD XML string.
*   **Targeted Validation**: Optionally specifies `validate_parts` (e.g., `Envelope`, `Header`, `Body`, `Fault`) to validate only specific sections of the SOAP message.
*   **Phase Agnostic**: Operates in the `access` phase for validating requests and the `body_filter` phase for validating responses.
*   **Robust Error Handling**:
    *   Configurable `on_validation_failure_status` and `on_validation_failure_body` to return to the client if validation fails.
    *   Option to `on_validation_failure_continue` processing even if validation fails.

<h2>Use Cases</h2>

*   **SOAP API Governance**: Enforce strict adherence to WSDL/XSD contracts for SOAP APIs.
*   **Data Integrity**: Prevent malformed or invalid SOAP messages, which could lead to backend errors or unexpected behavior.
*   **Security**: Mitigate XML-based injection attacks by validating against a known safe schema.
*   **Interoperability**: Enhance interoperability by enforcing strict adherence to SOAP standards.
*   **Early Fault Detection**: Catch invalid SOAP messages early in the API gateway, before they consume valuable backend resources.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`soap_validation_service_url`**: (string, required) The full URL of the external service endpoint that will perform the SOAP message validation.
*   **`message_source_type`**: (string, required, enum: `request_body`, `response_body`, `shared_context`) Specifies where to get the SOAP message (XML string) for validation.
*   **`message_source_name`**: (string, conditional) Required if `message_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the SOAP message string.
*   **`xsd_source_type`**: (string, required, enum: `literal`, `url`, `shared_context`) Specifies where to get the XSD schema definition for validation.
*   **`xsd_source_name`**: (string, conditional) Required if `xsd_source_type` is 'url' or 'shared_context'. This is the URL to the XSD file or the key in `kong.ctx.shared` holding the XSD string.
*   **`xsd_literal`**: (string, conditional) Required if `xsd_source_type` is 'literal'. The actual XSD schema XML string to use for validation.
*   **`validate_parts`**: (array of strings, optional, enum: `Envelope`, `Header`, `Body`, `Fault`, default: `{}`) Which specific parts of the SOAP message to validate. If empty, the external service should validate the entire message.
*   **`on_validation_failure_status`**: (number, default: `400`, between: `400` and `599`) The HTTP status code to return to the client if SOAP message validation fails.
*   **`on_validation_failure_body`**: (string, default: `"SOAP message validation failed."`) The response body to return to the client if SOAP message validation fails.
*   **`on_validation_failure_continue`**: (boolean, default: `false`) If `true`, request/response processing will continue even if SOAP message validation fails. If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to validate incoming SOAP request bodies against a literal XSD:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=soap-message-validation" \
    --data "config.soap_validation_service_url=http://soap-validator.example.com/validate" \
    --data "config.message_source_type=request_body" \
    --data "config.xsd_source_type=literal" \
    --data "config.xsd_literal=<xs:schema xmlns:xs=\"http://www.w3.org/2001/XMLSchema\">...</xs:schema>" \
    --data "config.validate_parts=Body" \
    --data "config.on_validation_failure_status=400" \
    --data "config.on_validation_failure_body=Invalid SOAP request body format."
```

**Enable on a Route to validate outgoing SOAP response bodies against an XSD from a URL:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=soap-message-validation" \
    --data "config.message_source_type=response_body" \
    --data "config.xsd_source_type=url" \
    --data "config.xsd_source_name=https://example.com/schemas/myServiceResponse.xsd" \
    --data "config.validate_parts=Envelope" \
    --data "config.on_validation_failure_continue=true"
```
