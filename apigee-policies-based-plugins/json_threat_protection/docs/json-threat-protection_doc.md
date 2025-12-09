# JSONThreatProtection Kong Plugin

## Purpose

The `JSONThreatProtection` plugin for Kong Gateway protects your APIs from various JSON-based attacks and resource exhaustion scenarios by enforcing configurable structural and size constraints on JSON payloads. This mirrors the functionality of Apigee's `JSONThreatProtection` policy, safeguarding your backend services from malicious or malformed input.

This plugin helps mitigate threats such as denial-of-service (DoS) attacks, memory overloads, and other vulnerabilities associated with oversized or overly complex JSON structures.

## Abilities and Features

*   **Flexible JSON Source**: Retrieves JSON content from either:
    *   **`request_body`**: The raw body of the client's incoming request.
    *   **`shared_context`**: A specified key within `kong.ctx.shared` that holds JSON content.
*   **Comprehensive Constraint Enforcement**: Enforces configurable limits on various aspects of the JSON structure:
    *   **`max_array_elements`**: Maximum number of elements allowed in any JSON array.
    *   **`max_container_depth`**: Maximum nesting depth of JSON objects and arrays.
    *   **`max_object_entry_count`**: Maximum number of properties allowed in any JSON object.
    *   **`max_object_entry_name_length`**: Maximum length of any JSON object property name.
    *   **`max_string_value_length`**: Maximum length of any string value within the JSON.
*   **Recursive Validation**: Recursively traverses the entire JSON payload to apply all configured checks.
*   **Robust Error Handling**:
    *   Configurable `on_violation_status` and `on_violation_body` to return to the client if a violation is detected.
    *   Option to `on_violation_continue` processing even after a violation, allowing for logging or other custom handling before potential termination by another policy.

<h2>Use Cases</h2>

*   **Denial-of-Service (DoS) Prevention**: Reject excessively large, deeply nested, or highly complex JSON payloads that could consume disproportionate server resources and lead to DoS.
*   **API Security**: Protect backend services from malformed or malicious JSON input that could lead to unexpected behavior or vulnerabilities.
*   **Input Validation**: Enforce strict adherence to expected JSON schema limits, preventing over-sized data elements.
*   **Resource Management**: Control the resource footprint of incoming requests by limiting the size and complexity of JSON data.
*   **Malware Transmission Prevention**: Limit the size of strings or objects to reduce the likelihood of transmitting large, hidden malicious code snippets.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`source_type`**: (string, required, enum: `request_body`, `shared_context`) Specifies where to get the JSON content from for threat protection.
*   **`source_name`**: (string, conditional) Required if `source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the JSON content (as a string or Lua table).
*   **`max_array_elements`**: (number, optional, min: `0`, max: `10000`) Maximum number of elements allowed in any JSON array. If `0`, this limit is disabled.
*   **`max_container_depth`**: (number, optional, min: `0`, max: `100`) Maximum nesting depth of JSON objects and arrays. If `0`, this limit is disabled.
*   **`max_object_entry_count`**: (number, optional, min: `0`, max: `10000`) Maximum number of properties allowed in any JSON object. If `0`, this limit is disabled.
*   **`max_object_entry_name_length`**: (number, optional, min: `0`, max: `1000`) Maximum length of any JSON object property name. If `0`, this limit is disabled.
*   **`max_string_value_length`**: (number, optional, min: `0`, max: `1000000`) Maximum length of any string value within the JSON payload. If `0`, this limit is disabled.
*   **`on_violation_status`**: (number, default: `400`, between: `400` and `599`) The HTTP status code to return if a JSON threat protection violation is detected.
*   **`on_violation_body`**: (string, default: "JSON threat protection violation.") The response body to return if a violation is detected.
*   **`on_violation_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if a JSON threat protection violation is detected. If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to enforce strict JSON structure limits for incoming requests:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=json-threat-protection" \
    --data "config.source_type=request_body" \
    --data "config.max_array_elements=100" \
    --data "config.max_container_depth=5" \
    --data "config.max_object_entry_count=50" \
    --data "config.max_object_entry_name_length=30" \
    --data "config.max_string_value_length=1000" \
    --data "config.on_violation_status=400" \
    --data "config.on_violation_body=Malformed or oversized JSON payload detected." \
    --data "config.on_violation_continue=false"
```

**Enable on a Route to apply protection to JSON content from shared context:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=json-threat-protection" \
    --data "config.source_type=shared_context" \
    --data "config.source_name=processed_json_data" \
    --data "config.max_container_depth=3" \
    --data "config.max_object_entry_count=20" \
    --data "config.on_violation_continue=true"
```
