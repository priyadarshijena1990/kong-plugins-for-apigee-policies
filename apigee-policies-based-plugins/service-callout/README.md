# Kong Plugin: Service Callout

This plugin makes an HTTP/HTTPS call to an external service or endpoint during the API flow. It is designed to mimic the functionality of Apigee's `ServiceCallout` policy.

A key feature of this plugin is its ability to operate in either a synchronous (waiting for a response) or an asynchronous "fire and forget" mode, offering flexibility for different integration needs.

## How it Works

The plugin can be configured to make a synchronous or asynchronous call to an external URL.

*   **Synchronous Mode** (`wait_for_response = true`, default): The plugin makes the HTTP call and waits for the response before allowing the request to proceed. The response from the callout can be stored in the request context for use by other plugins.
*   **Asynchronous Mode** (`wait_for_response = false`): The plugin initiates the HTTP call in a background timer and immediately allows the main request flow to continue without waiting for the callout to complete. This is useful for non-critical tasks like logging or analytics.

## Configuration

*   **`callout_url`**: (string, required) The full URL of the external service endpoint to call.
*   **`method`**: (string, default: `POST`) The HTTP method for the callout request.
*   **`headers`**: (map, optional) Headers to send with the callout request.
*   **`request_body_source_type`**: (string, default: `request_body`, enum: `request_body`, `shared_context`, `none`) Specifies the source of the request body for the callout.
*   **`request_body_source_name`**: (string, conditional) Required if `request_body_source_type` is `shared_context`. The key in `kong.ctx.shared` that holds the content for the body.
*   **`wait_for_response`**: (boolean, default: `true`) If `false`, the plugin makes the callout asynchronously.
*   **`response_to_shared_context_key`**: (string, optional) If set and in synchronous mode, the external service's response will be stored in `kong.ctx.shared` under this key. The response body will be automatically JSON-decoded if possible.
*   **`on_error_status`**: (number, default: `500`) In synchronous mode, the HTTP status to return if the callout fails and `on_error_continue` is `false`.
*   **`on_error_body`**: (string, default: "External Callout failed.") In synchronous mode, the response body to return on failure.
*   **`on_error_continue`**: (boolean, default: `false`) In synchronous mode, if `true`, continue processing the main request even if the callout fails.

### Example: Asynchronous Logging

This example enables the plugin globally to send the request body to a logging service without blocking the client request.

```yaml
plugins:
- name: service-callout
  config:
    callout_url: https://logs.example.com/ingest
    method: POST
    request_body_source_type: request_body
    wait_for_response: false
    headers:
      Content-Type: application/json
```

### Example: Synchronous Data Enrichment

This example enables the plugin on a specific service to fetch extra user data and add it to the request context.

```yaml
plugins:
- name: service-callout
  config:
    callout_url: https://users.internal/get_profile
    method: POST
    request_body_source_type: shared_context
    request_body_source_name: user_lookup_payload
    wait_for_response: true
    response_to_shared_context_key: user_profile
    on_error_continue: true
```
