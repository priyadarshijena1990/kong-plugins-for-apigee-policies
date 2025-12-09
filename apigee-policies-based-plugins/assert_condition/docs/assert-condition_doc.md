# AssertCondition Kong Plugin

## Purpose

The `AssertCondition` plugin for Kong Gateway evaluates a configurable Lua expression. If this expression (the "condition") evaluates to `false`, the plugin immediately terminates the request and returns a custom fault response to the client. This mimics the functionality of Apigee's `AssertCondition` policy, serving as a powerful tool for validating preconditions and enforcing business rules early in your API proxy flow.

It's designed to ensure that specific criteria are met before allowing a request to proceed to upstream services.

## Abilities and Features

*   **Configurable Lua Condition**: Define a `lua_condition` – a Lua expression that can access `kong` context variables (e.g., `kong.ctx.shared`, `kong.request`, `kong.response`). The request proceeds only if this condition evaluates to `true`.
*   **Custom Fault Response**: When the assertion fails (condition is `false`), the plugin returns a customizable error response, including:
    *   HTTP `status` code (e.g., 400, 401, 403).
    *   A custom `body` (e.g., JSON error object, plain text).
    *   Optional `headers` to include in the fault response.
    *   An optional HTTP `reason_phrase`.
*   **Content-Type Inference**: If no `Content-Type` header is explicitly provided in `on_assertion_failure_headers`, the plugin will attempt to infer it as `application/json` (if the `body` looks like JSON) or `text/plain`.
*   **Early Failure Detection**: Operates in the `access` phase, allowing it to validate requests and block invalid ones before they consume upstream resources.

<h2>Use Cases</h2>

*   **Mandatory Parameter Checks**: Assert that essential headers, query parameters, or fields in the request body are present and contain valid values.
*   **Business Rule Enforcement**: Verify that specific business rules are met based on information extracted from the request or previous plugins (e.g., `kong.ctx.shared.user_tier == "premium"`).
*   **Authentication/Authorization Guards**: Assert that an authentication flag or an authorization scope (set by a preceding authentication/authorization plugin) is `true`.
*   **Precondition Validation**: Confirm that all necessary preconditions for a successful upstream call are satisfied.
*   **API Governance**: Enforce API design contracts by validating incoming request structures or data.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`lua_condition`**: (string, required) A Lua expression that must evaluate to `true` for the request to proceed. If it evaluates to `false` or `nil`, the assertion fails, and a fault is raised. This expression can access `kong` variables.
    *   **Examples**:
        *   `kong.request.get_header("X-Auth-Token") ~= nil`
        *   `kong.request.get_query_arg("id") and tonumber(kong.request.get_query_arg("id")) > 0`
        *   `kong.ctx.shared.is_authorized == true`
        *   `kong.request.get_path() == "/admin" and kong.ctx.shared.user_role == "admin"`
*   **`on_assertion_failure_status`**: (number, default: `400`, between: `400` and `599`) The HTTP status code to return when the assertion fails.
*   **`on_assertion_failure_body`**: (string, default: `"Assertion failed: Invalid request."`) The content of the response body when the assertion fails.
*   **`on_assertion_failure_headers`**: (map, optional) A map of custom headers to include in the failure response.
*   **`on_assertion_failure_reason_phrase`**: (string, optional) The HTTP reason phrase for the failure response. If not provided, Kong will use a default for the given status code.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to assert that a required header is present:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=assert-condition" \
    --data 'config.lua_condition=kong.request.get_header("X-Required-Header") ~= nil' \
    --data "config.on_assertion_failure_status=400" \
    --data "config.on_assertion_failure_body=Missing required 'X-Required-Header'." \
    --data "config.on_assertion_failure_headers.X-Error-Code=MISSING_HEADER"
```

**Enable on a Route to assert that a user is authorized based on shared context data:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=assert-condition" \
    --data 'config.lua_condition=kong.ctx.shared.is_authorized == true' \
    --data "config.on_assertion_failure_status=401" \
    --data 'config.on_assertion_failure_body={"message":"Unauthorized access.","reason":"Not authorized."}' \
    --data "config.on_assertion_failure_headers.Content-Type=application/json" \
    --data "config.on_assertion_failure_reason_phrase=Unauthorized"
```
