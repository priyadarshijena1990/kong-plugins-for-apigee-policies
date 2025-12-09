# FlowCallout Kong Plugin

## Purpose

The `FlowCallout` plugin for Kong Gateway allows you to internally invoke a dedicated Kong Service, effectively mimicking Apigee's `FlowCallout` policy. This enables the execution of reusable, encapsulated logic (a "shared flow") defined as another Kong Service within your API proxy's processing pipeline.

This mechanism is ideal for promoting modularity, reusability, and consistency by centralizing common functionalities that might be needed by multiple API proxies or at various points within an API flow.

## Abilities and Features

*   **Internal Service Invocation**: Makes an internal sub-request to a configurable `shared_flow_service_name` (a Kong Service). The original client's request method, URI, headers, and body are passed to this internal service.
*   **Shared Context Integration**: The full response from the internal shared flow (status, headers, and body) can be stored in `kong.ctx.shared` under a specified key, making it accessible to subsequent plugins in the main request flow.
*   **Robust Error Handling**:
    *   Configurable `on_flow_error_status` and `on_flow_error_body` to return to the client if the internal shared flow call fails.
    *   Option to `on_flow_error_continue` processing the main request even if the internal shared flow call encounters an error.
*   **Original Request Body Preservation**: The `preserve_original_request_body` setting acts as a hint; generally, the original request body remains available for the main upstream even after the internal sub-request, unless explicitly modified by the shared flow.

<h2>Important Note</h2>

The "shared flow" referenced by this plugin (`shared_flow_service_name`) must be a separately configured Kong Service. This Service should have its own routes, plugins, and upstream configurations that define the reusable logic you wish to execute.

<h2>Use Cases</h2>

*   **Reusable Security Checks**: Centralize common authentication, authorization, or threat protection logic in a shared flow service that all APIs can call.
*   **Centralized Logging**: Implement standardized logging routines that send request/response details to an external logging service, invoked from various points in your API flows.
*   **Data Transformation Pipelines**: Apply complex or common data transformations by sending the request/response to a shared flow service dedicated to that transformation logic.
*   **Standardized Error Handling**: Define a shared flow service that formats and handles specific error conditions consistently across multiple APIs.
*   **Internal Micro-Orchestration**: Coordinate multiple internal steps or lookups within a shared flow service before the main request proceeds to its final upstream.

## Configuration

The plugin supports the following configuration parameters:

*   **`shared_flow_service_name`**: (string, required) The name of the Kong Service that represents the "shared flow" to be executed internally. This Service must exist and be configured.
*   **`preserve_original_request_body`**: (boolean, default: `true`) If `true`, the plugin ensures the original client request body (as it was before the `FlowCallout`) remains available for the main upstream processing. (This is generally the default behavior of `kong.service.request()`).
*   **`on_flow_error_status`**: (number, default: `500`, between: `400` and `599`) The HTTP status code to return to the client if the internal shared flow call fails and `on_flow_error_continue` is `false`.
*   **`on_flow_error_body`**: (string, default: "Shared Flow execution failed.") The response body to return to the client if the internal shared flow call fails and `on_flow_error_continue` is `false`.
*   **`on_flow_error_continue`**: (boolean, default: `false`) If `true`, the main request processing will continue even if the internal shared flow call encounters an error. If `false`, the request will be terminated.
*   **`store_flow_response_in_shared_context_key`**: (string, optional) If set, the internal shared flow's full response (status, headers, body) will be stored in `kong.ctx.shared` under this key, as a Lua table.

<h3>Example Configuration (via Admin API)</h3>

**1. Define a Kong Service for your shared flow:**

```bash
curl -X POST http://localhost:8001/services \
    --data "name=my-shared-security-flow" \
    --data "url=http://127.0.0.1:8000/internal-security-logic" # This URL can point to a mock service or a non-existent one if plugins handle all logic
```
Then, add plugins to `my-shared-security-flow` (e.g., `rate-limiting`, `jwt`, `request-transformer` to modify headers).

**2. Enable `FlowCallout` on your API's Service or Route:**

```bash
curl -X POST http://localhost:8001/services/{your_api_service_id}/plugins \
    --data "name=flow-callout" \
    --data "config.shared_flow_service_name=my-shared-security-flow" \
    --data "config.store_flow_response_in_shared_context_key=security_check_result" \
    --data "config.on_flow_error_continue=false" \
    --data "config.on_flow_error_status=403" \
    --data "config.on_flow_error_body=Access denied by security flow."
```

## Accessing Information

If `store_flow_response_in_shared_context_key` was configured, the internal shared flow's response will be stored in `kong.ctx.shared` as a Lua table.

**Example (in a custom Lua plugin's `access` phase):**

```lua
local security_result = kong.ctx.shared.security_check_result

if security_result and security_result.status == 200 then
    kong.log.notice("Shared security flow passed. Response: ", security_result.body)
    -- Continue with main logic
else
    kong.log.warn("Shared security flow failed or returned non-200. Status: ", security_result.status)
    -- Take action based on failure
end
```
