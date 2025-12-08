# XMLThreatProtection Kong Plugin

## Purpose

The `XMLThreatProtection` plugin for Kong Gateway protects your APIs from various XML-based attacks and resource exhaustion scenarios by enforcing configurable structural and size constraints on XML payloads. This mirrors the functionality of Apigee's `XMLThreatProtection` policy, safeguarding your backend services from malicious or malformed input.

**Important**: Due to the complexity of XML parsing and robust threat detection, this plugin relies on an *external service* to perform the actual XML threat protection. The plugin extracts the XML message, sends it along with configured limits to this external service, and then processes the service's response to determine if any violations occurred.

## Abilities and Features

*   **Delegation to External Service**: All complex XML parsing and threat protection logic is handled by a configurable `xml_threat_protection_service_url` (an external microservice).
*   **Flexible XML Source**: Retrieves the XML message (as a string) from either:
    *   **`request_body`**: The raw body of the client's incoming request.
    *   **`shared_context`**: A specified key within `kong.ctx.shared` that holds XML content.
*   **Comprehensive Constraint Enforcement**: Enforces configurable limits on various aspects of the XML structure (delegated to the external service):
    *   **`max_element_depth`**: Maximum nesting depth of XML elements.
    *   **`max_element_count`**: Maximum number of XML elements allowed.
    *   **`max_attribute_count`**: Maximum number of attributes allowed per XML element.
    *   **`max_attribute_name_length`**: Maximum length of any XML attribute name.
    *   **`max_attribute_value_length`**: Maximum length of any XML attribute value.
    *   **`max_entity_expansion`**: Maximum number of entity expansions (to mitigate XML bombs like Billion Laughs).
*   **Robust Error Handling**:
    *   Configurable `on_violation_status` and `on_violation_body` to return to the client if a violation is detected.
    *   Option to `on_violation_continue` processing even after a violation, allowing for logging or other custom handling before potential termination by another policy.

<h2>Use Cases</h2>

*   **XML Denial-of-Service (DoS) Prevention**: Mitigate attacks like XML bombs by limiting entity expansions and preventing excessively large or complex XML payloads.
*   **XML External Entity (XXE) Prevention**: Control entity expansion to reduce the risk of XXE attacks.
*   **API Security**: Protect backend services from malformed or malicious XML input that could lead to unexpected behavior, parser vulnerabilities, or resource exhaustion.
*   **Data Structure Enforcement**: Ensure incoming XML adheres to expected structural and size limits.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`xml_threat_protection_service_url`**: (string, required) The full URL of the external service endpoint that will perform the XML threat protection checks.
*   **`message_source_type`**: (string, required, enum: `request_body`, `shared_context`) Specifies where to get the XML message (XML string) for threat protection.
*   **`message_source_name`**: (string, conditional) Required if `message_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the XML message string.
*   **`max_element_depth`**: (number, optional, min: `0`, max: `100`) Maximum nesting depth of XML elements. If `0`, this limit is disabled.
*   **`max_element_count`**: (number, optional, min: `0`, max: `10000`) Maximum number of XML elements allowed in the message. If `0`, this limit is disabled.
*   **`max_attribute_count`**: (number, optional, min: `0`, max: `1000`) Maximum number of attributes allowed per XML element. If `0`, this limit is disabled.
*   **`max_attribute_name_length`**: (number, optional, min: `0`, max: `1000`) Maximum length of any XML attribute name. If `0`, this limit is disabled.
*   **`max_attribute_value_length`**: (number, optional, min: `0`, max: `1000000`) Maximum length of any XML attribute value. If `0`, this limit is disabled.
*   **`max_entity_expansion`**: (number, optional, min: `0`, max: `1000`) Maximum number of entity expansions allowed (to mitigate XML bombs). If `0`, this limit is disabled.
*   **`on_violation_status`**: (number, default: `400`, between: `400` and `599`) The HTTP status code to return to the client if an XML threat protection violation is detected.
*   **`on_violation_body`**: (string, default: "XML threat protection violation.") The response body to return to the client if a violation is detected.
*   **`on_violation_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if an XML threat protection violation is detected. If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to enforce strict XML structure limits for incoming requests:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=xml-threat-protection" \
    --data "config.xml_threat_protection_service_url=http://xml-security-service.example.com/protect" \
    --data "config.message_source_type=request_body" \
    --data "config.max_element_depth=5" \
    --data "config.max_element_count=200" \
    --data "config.max_attribute_count=10" \
    --data "config.max_attribute_value_length=1000" \
    --data "config.max_entity_expansion=50" \
    --data "config.on_violation_status=400" \
    --data "config.on_violation_body=Malformed or oversized XML payload detected." \
    --data "config.on_violation_continue=false"
```

**Enable on a Route to apply protection to XML content from shared context, allowing continuation:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=xml-threat-protection" \
    --data "config.xml_threat_protection_service_url=http://xml-security-service.example.com/protect" \
    --data "config.message_source_type=shared_context" \
    --data "config.message_source_name=cleaned_xml_data" \
    --data "config.max_element_depth=3" \
    --data "config.max_element_count=50" \
    --data "config.on_violation_continue=true"
```
