# ExternalCallout Kong Plugin

## Purpose

The `ExternalCallout` plugin for Kong Gateway allows you to make an HTTP/HTTPS call to an external service or endpoint during the API flow. This mirrors the functionality of Apigee's `ExternalCallout` policy, primarily designed for integrating with external logging, monitoring, or security systems.

A key feature of this plugin is its ability to operate in either a synchronous (waiting for a response) or a "fire and forget" (not waiting for a response) mode, offering flexibility for different integration needs.

## Abilities and Features

*   **Configurable External Service Invocation**: Makes an HTTP/HTTPS request to a configurable `callout_url`.
*   **Request Customization**: Supports configurable HTTP `method` (GET, POST, etc.) and custom `headers` for the callout request.
*   **Flexible Request Body Source**: The body sent to the external service can be derived from:
    *   **`request_body`**: The raw body of the original client request.
    *   **`shared_context`**: Content stored under a specified key in `kong.ctx.shared` (supports JSON serialization for Lua tables).
    *   **`none`**: No body is sent to the external service.
*   **Synchronous or "Fire and Forget" Mode**:
    *   If `wait_for_response` is `true` (default): The plugin waits for the external service's response.
        *   The response (status, headers, body) can be stored in `kong.ctx.shared`.
        *   Robust error handling is available (exit or continue on failure with custom status/body).
    *   If `wait_for_response` is `false`: The plugin makes the callout but does not wait for a response. The main API flow continues immediately. Error handling and response storage are bypassed for this mode.

<h2>Important Note</h2>

When `wait_for_response` is `false`, the underlying HTTP call is still initiated. However, the Kong plugin does not block the main request processing to await its completion. This is suitable for non-critical logging, analytics, or event dispatch where the external service's response is not needed for the main API transaction.

<h2>Use Cases</h2>

*   **Custom Logging & Auditing**: Send API request/response details, client information, or custom events to an external logging system (e.g., Splunk, ELK stack) for detailed analysis and auditing, often in a fire-and-forget mode.
*   **Security Scanning & Threat Detection**: Dispatch requests to a Web Application Firewall (WAF) or a custom threat detection service for asynchronous or synchronous analysis. Blocking the main request (i.e., `wait_for_response=true`) is common for critical security checks.
*   **Data Masking/Anonymization**: Send sensitive data fields to an external service for masking before they reach the backend. This typically requires waiting for the masked data (`wait_for_response=true`).
*   **External Analytics**: Push custom metrics or events to an external analytics platform without impacting the primary API flow ("fire and forget").
*   **Webhook & Notification Dispatch**: Trigger external webhooks, messaging services, or notification systems in response to API events.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`callout_url`**: (string, required) The full URL of the external service endpoint to call.
*   **`method`**: (string, default: `POST`, enum: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`) The HTTP method for the callout request.
*   **`headers`**: (map, optional) A dictionary of custom headers to send with the callout request.
*   **`request_body_source_type`**: (string, default: `request_body`, enum: `request_body`, `shared_context`, `none`) Specifies where to get the request body to send to the external service.
*   **`request_body_source_name`**: (string, conditional) Required if `request_body_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the content to send as the body. If the value is a Lua table, it will be JSON-encoded.
*   **`wait_for_response`**: (boolean, default: `true`) If `false`, the plugin makes the callout but does not wait for the external service's response. Error handling and response storage in `kong.ctx.shared` are skipped in this mode.
*   **`response_to_shared_context_key`**: (string, optional) If set and `wait_for_response` is `true`, the external service's full response (status, headers, body) will be stored in `kong.ctx.shared` under this key, as a Lua table.
*   **`on_error_status`**: (number, default: `500`, between: `400` and `599`) The HTTP status code to return to the client if the external callout fails, `wait_for_response` is `true`, and `on_error_continue` is `false`.
*   **`on_error_body`**: (string, default: "External Callout failed.") The response body to return to the client if the external callout fails, `wait_for_response` is `true`, and `on_error_continue` is `false`.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, the main request processing will continue even if the external callout fails (only applicable if `wait_for_response` is `true`). If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable globally for "fire and forget" logging to an external analytics service:**

```bash
curl -X POST http://localhost:8001/plugins \
    --data "name=external-callout" \
    --data "config.callout_url=https://analytics.example.com/log" \
    --data "config.method=POST" \
    --data "config.request_body_source_type=request_body" \
    --data "config.wait_for_response=false" \
    --data "config.headers.Content-Type=application/json"
```

**Enable on a Service for a critical security check, waiting for response and potentially blocking:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=external-callout" \
    --data "config.callout_url=https://security.example.com/scan" \
    --data "config.method=POST" \
    --data "config.request_body_source_type=shared_context" \
    --data "config.request_body_source_name=request_payload_to_scan" \
    --data "config.wait_for_response=true" \
    --data "config.response_to_shared_context_key=security_scan_result" \
    --data "config.on_error_continue=false" \
    --data "config.on_error_status=403" \
    --data "config.on_error_body=Security check failed."
```

<h2>Accessing Information</h2>

If `response_to_shared_context_key` was configured and `wait_for_response` was `true`, the external service's response will be stored in `kong.ctx.shared` as a Lua table containing `status`, `headers`, and `body`.

**Example (in a custom Lua plugin's `access` phase):**

```lua
local scan_result = kong.ctx.shared.security_scan_result

if scan_result and scan_result.status == 200 and scan_result.body == "CLEAN" then
    kong.log.notice("Security scan passed. Continuing request.")
elseif scan_result then
    kong.log.warn("Security scan failed or returned non-CLEAN result. Status: ", scan_result.status, " Body: ", scan_result.body)
    -- Potentially raise a fault here if on_error_continue was true for ExternalCallout
end
```
