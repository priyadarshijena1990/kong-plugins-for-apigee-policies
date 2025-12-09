# Kong Plugin: JSON Threat Protection

This plugin protects your APIs from content-level attacks by enforcing limits on the structure and size of JSON payloads. It is designed to mimic the functionality of Apigee's `JSONThreatProtection` policy.

This is a crucial security policy for preventing application-level Denial of Service (DoS) attacks that use overly large or complex JSON to exhaust server resources.

## How it Works

The plugin parses an incoming JSON payload (from the request body or the shared context) and recursively validates it against a set of configured limits. If any limit is exceeded, the request is blocked.

The plugin checks the following constraints:
*   **Maximum Array Elements**: The total number of elements in any array.
*   **Maximum Container Depth**: The deepest level of nested objects or arrays.
*   **Maximum Object Properties**: The number of key-value pairs in any single object.
*   **Maximum Property Name Length**: The length of any key/property name.
*   **Maximum String Value Length**: The length of any string value.

When the source is the request body, the plugin will only run if the `Content-Type` header is `application/json`.

## Configuration

*   **`source_type`**: (string, required, enum: `request_body`, `shared_context`) Where to get the JSON content from.
*   **`source_name`**: (string, conditional) The context key if `source_type` is `shared_context`.
*   **`max_array_elements`**: (number, optional) Max elements in an array.
*   **`max_container_depth`**: (number, optional) Max nesting depth.
*   **`max_object_entry_count`**: (number, optional) Max properties in an object.
*   **`max_object_entry_name_length`**: (number, optional) Max length of a property name.
*   **`max_string_value_length`**: (number, optional) Max length of a string value.
*   **`on_violation_continue`**: (boolean, default: `false`) If `true`, allow the request to proceed even if a violation is detected.
*   **`on_violation_*`**: Configures the status and body to return on a violation if `on_violation_continue` is `false`.

### Example: Basic Protection on a Service

This example applies a default set of protections to all JSON requests for a service.

```yaml
plugins:
- name: json-threat-protection
  config:
    source_type: request_body
    max_array_elements: 100
    max_container_depth: 10
    max_object_entry_count: 50
    max_string_value_length: 10000
    on_violation_status: 400
    on_violation_body: >
      {
        "error": "Request payload exceeds complexity limits."
      }
```
