# RaiseFault Kong Plugin

## Purpose

The `RaiseFault` plugin for Kong Gateway provides a mechanism to immediately stop the current request processing flow and return a custom error response to the client. This mirrors the functionality of Apigee's `RaiseFault` policy, enabling controlled, custom error handling for specific conditions within your API proxy.

It's primarily used for situations where you want to terminate the request early due to validation failures, business logic errors, or security concerns, and provide a consistent, informative error message to the API consumer.

## Abilities and Features

*   **Custom Error Response**: Configure the HTTP `status` code (e.g., 400, 401, 500), a custom `body` (e.g., JSON error object, plain text), and additional `headers` for the error response.
*   **Optional Reason Phrase**: Specify an HTTP `reason_phrase` to accompany the status code.
*   **Conditional Execution**: Optionally, the fault can be raised only if a provided `lua_condition` (a Lua expression) evaluates to `true`. This expression has access to `kong` context variables (e.g., `kong.ctx.shared`, `kong.request`).
*   **Content-Type Inference**: If no `Content-Type` header is explicitly provided in `headers`, the plugin will attempt to infer it as `application/json` (if the `body` looks like JSON) or `text/plain`.

<h2>Use Cases</h2>

*   **Input Validation**: Reject requests with missing required parameters, invalid query values, incorrect header formats, or malformed request bodies.
*   **Business Logic Enforcement**: Terminate processing if a specific business rule is violated (e.g., a user attempts an action for which they lack permission, determined by an earlier plugin).
*   **Security Checks**: Block requests that fail security validations, such as unauthorized access attempts or detection of malicious patterns (e.g., after a `SanitizeUserPrompt` plugin identifies an issue).
*   **Rate Limit/Quota Overrides**: Integrate with other plugins to stop processing if rate limits are exceeded.
*   **Controlled Error Responses**: Standardize the format and content of error messages returned to clients across various fault conditions.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`status`**: (number, required, between: `400` and `599`) The HTTP status code to return in the fault response. Typical values include `400` (Bad Request), `401` (Unauthorized), `403` (Forbidden), `404` (Not Found), `406` (Not Acceptable), `429` (Too Many Requests), `500` (Internal Server Error).
*   **`body`**: (string, required) The content of the response body for the fault. This can be plain text, HTML, or a JSON string (e.g., `{"error": "Invalid API Key"}`).
*   **`headers`**: (map, optional) A map of custom headers to include in the fault response (e.g., `{"X-Error-Code": "AUTH_001"}`).
*   **`reason_phrase`**: (string, optional) The HTTP reason phrase (e.g., "Bad Request") to accompany the status code. If not provided, Kong will use a default for the given status code.
*   **`lua_condition`**: (string, optional) A Lua expression that must evaluate to `true` for the fault to be raised. This expression has access to `kong` context variables. If this field is omitted, the `RaiseFault` policy will always execute when reached in the request flow.
    *   **Examples**:
        *   `kong.ctx.shared.is_invalid_user == true`
        *   `kong.request.get_header("X-Auth-Failed") ~= nil`
        *   `kong.request.get_query_arg("api_key") == nil`
        *   `tonumber(kong.request.get_header("X-Request-Count")) > 10`

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to return a generic "Bad Request" if a custom flag is set:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=raise-fault" \
    --data "config.status=400" \
    --data 'config.body={"error": {"code": "INVALID_INPUT", "message": "The request contained invalid data."}}' \
    --data "config.headers.Content-Type=application/json" \
    --data "config.reason_phrase=Bad Request" \
    --data "config.lua_condition=kong.ctx.shared.has_invalid_input == true"
```

**Enable on a Route to block requests if a mandatory query parameter is missing:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=raise-fault" \
    --data "config.status=400" \
    --data 'config.body=Missing required query parameter "id".' \
    --data "config.reason_phrase=Missing Parameter" \
    --data 'config.lua_condition=kong.request.get_query_arg("id") == nil'
```

**Enable globally to act as a fallback error if a specific header is present:**

```bash
curl -X POST http://localhost:8001/plugins \
    --data "name=raise-fault" \
    --data "config.status=500" \
    --data 'config.body={"error": {"code": "INTERNAL_SERVER_ERROR", "message": "An unexpected error occurred."}}' \
    --data "config.headers.Content-Type=application/json" \
    --data "config.lua_condition=kong.ctx.shared.internal_error_flag == true"
```
