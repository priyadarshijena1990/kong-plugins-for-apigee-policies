# RegularExpressionProtection Kong Plugin

## Purpose

The `RegularExpressionProtection` plugin for Kong Gateway is designed to protect your APIs from content-based attacks by evaluating various parts of the incoming request against a set of predefined regular expressions. This mirrors the functionality of Apigee's `RegularExpressionProtection` policy, helping to prevent various injection attacks like SQL injection, XSS (Cross-Site Scripting), and NoSQL injection.

By matching known malicious patterns in client input, this plugin acts as a crucial first line of defense, ensuring that only safe and expected content reaches your backend services.

## Abilities and Features

*   **Multi-Source Protection**: Apply regular expression checks to multiple parts of the incoming request:
    *   **`header`**: HTTP request headers.
    *   **`query`**: URL query parameters.
    *   **`path`**: The full request URI path.
    *   **`body`**: The raw request body or specific fields within a JSON request body (using JSON paths).
*   **Multiple Pattern Matching**: For each configured source, define one or more regular expression `patterns` to match against its content.
*   **Configurable Action on Match**:
    *   **`abort` (default)**: If any pattern matches, the request is immediately terminated, and a custom error response is returned to the client.
    *   **`continue`**: If a pattern matches, the violation is logged, but the request is allowed to proceed. This is useful for auditing or logging without blocking the request.
*   **Customizable Violation Response**: Configure the HTTP `violation_status` code and `violation_body` content for requests that are blocked.

<h2>Important Note</h2>

Careful construction of regular expressions is vital. Overly broad patterns can lead to false positives (blocking legitimate traffic), while overly narrow patterns can fail to detect threats. Complex regular expressions can also impact performance. It is recommended to thoroughly test your patterns.

<h2>Use Cases</h2>

*   **SQL Injection Prevention**: Detect and block common SQL injection patterns (e.g., `OR 1=1`, `UNION SELECT`) in query parameters, headers, or request body fields.
*   **XSS Protection**: Identify and block common cross-site scripting patterns in user-provided input within headers or JSON fields.
*   **NoSQL Injection Prevention**: Protect against patterns used in NoSQL injection attacks.
*   **Input Format Validation**: Enforce specific input formats for specific fields (e.g., ensure an ID is purely numeric, or a name contains only alphabetic characters).
*   **Sensitive Data Blocking**: Prevent accidental or malicious inclusion of sensitive data (e.g., credit card numbers, PII) in inappropriate request parts.

## Configuration

The plugin supports the following configuration parameters:

*   **`sources`**: (array of records, required) A list defining which request components to check and what patterns to apply. Each record has:
    *   **`source_type`**: (string, required, enum: `header`, `query`, `path`, `body`) The type of request component.
    *   **`source_name`**: (string, conditional)
        *   Required for `header`: The name of the HTTP header (e.g., `User-Agent`).
        *   Required for `query`: The name of the query parameter (e.g., `search_term`).
        *   Required for `body`: A dot-notation JSON path (e.g., `user.comment`) to check within a JSON request body. If `.` or empty, the entire raw body is checked.
        *   Not required for `path`: The entire request URI path is checked.
    *   **`patterns`**: (array of strings, required) A list of regular expression patterns (Lua/Nginx regex syntax) to match against the content of this source.
*   **`match_action`**: (string, default: `abort`, enum: `abort`, `continue`) The action to take if any pattern matches.
*   **`violation_status`**: (number, default: `403`, between: `400` and `599`) The HTTP status code to return when a violation is detected and `match_action` is `abort`.
*   **`violation_body`**: (string, default: `"Malicious input detected. Request blocked."`) The response body to return when a violation is detected and `match_action` is `abort`.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to protect against SQL injection in query parameters and XSS in headers:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=regular-expression-protection" \
    --data "config.sources.1.source_type=query" \
    --data "config.sources.1.source_name=id" \
    --data "config.sources.1.patterns.1=(UNION\\s+SELECT)" \
    --data "config.sources.1.patterns.2=(\'\\s*OR\\s*\'1\'=\'1)" \
    --data "config.sources.2.source_type=header" \
    --data "config.sources.2.source_name=X-User-Agent" \
    --data "config.sources.2.patterns.1=(&lt;script&gt;)" \
    --data "config.match_action=abort" \
    --data "config.violation_status=403" \
    --data "config.violation_body=Forbidden: Potential injection attack detected."
```

**Enable on a Route to check a JSON request body field for prohibited characters:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=regular-expression-protection" \
    --data "config.sources.1.source_type=body" \
    --data "config.sources.1.source_name=user.comment" \
    --data "config.sources.1.patterns.1=[;&lt;&gt;"]" \
    --data "config.match_action=continue" \
    --data "config.violation_body=Comment contains prohibited characters, but processing continues for logging."
```