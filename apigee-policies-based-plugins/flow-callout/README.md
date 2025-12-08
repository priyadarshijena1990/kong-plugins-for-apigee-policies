# Kong Plugin: Flow Callout

This plugin simulates the functionality of Apigee's `FlowCallout` policy by making an internal sub-request to another Kong Service, effectively executing a reusable "shared flow" of plugins.

## How it Works

This plugin allows you to define a common set of plugins on a dedicated Kong Service (a "shared flow service") and then call that service from any other API route. This is useful for centralizing logic like custom authentication, logging, or enrichment that needs to be applied to multiple APIs.

When a request hits a route with the `flow-callout` plugin, the plugin will:
1.  Pause the current request.
2.  Make an internal request to the specified "shared flow" Kong Service. This internal request inherits the method, headers, path, and body of the original request.
3.  The full plugin chain of the shared flow service is executed.
4.  After the internal call completes, this plugin can store the response from the shared flow in the request context.
5.  The plugin will then either terminate the original request or allow it to continue, based on the success or failure of the shared flow call.

### Body Preservation

A critical feature is the `preserve_original_request_body` flag. When Kong plugins read the request body, it is consumed and will not be available to the final upstream service.

*   If `preserve_original_request_body` is `true` (default), this plugin will capture the body and restore it after the flow callout is complete, ensuring that your upstream service receives the original POST/PUT/PATCH body.
*   If `false`, the body will not be restored. This is suitable if the shared flow is the only thing that needs the body, or for GET/HEAD/etc. requests.

## Configuration

*   **`shared_flow_service_name`**: (string, required) The name of the Kong Service that represents the "shared flow" to be executed.
*   **`preserve_original_request_body`**: (boolean, default: `true`) If `true`, restores the original request body after the callout is complete.
*   **`store_flow_response_in_shared_context_key`**: (string, optional) If set, the shared flow's full response (status, headers, body) will be stored in `kong.ctx.shared` under this key.
*   **`on_flow_error_status`**: (number, default: `500`) The HTTP status to return if the flow callout fails and `on_flow_error_continue` is `false`.
*   **`on_flow_error_body`**: (string, default: "Shared Flow execution failed.") The response body to return on failure.
*   **`on_flow_error_continue`**: (boolean, default: `false`) If `true`, continue processing the main request even if the flow callout fails.

### Example Setup

**1. Define a "Shared Flow" Service**

Create a Kong Service that points to a mock upstream or a specific internal endpoint. Apply your common plugins to this service.

```yaml
services:
- name: my-auth-shared-flow
  url: http://mock.bin/request # Upstream for the shared flow
  plugins:
  - name: rate-limiting
    config:
      policy: local
      minute: 5
  - name: key-auth
    config:
      key_names:
      - apikey
```

**2. Apply `flow-callout` to your Main API**

Apply the `flow-callout` plugin to the public-facing API that needs the common authentication logic.

```yaml
services:
- name: my-public-api
  url: http://my-real-upstream.com
  routes:
  - name: my-public-api-route
    paths:
    - /my-api
  plugins:
  - name: flow-callout
    config:
      shared_flow_service_name: my-auth-shared-flow
      on_flow_error_status: 401
      on_flow_error_body: "Authentication failed in shared flow."
```

Now, when a request comes to `/my-api`, the `flow-callout` plugin will first trigger an internal request to the `my-auth-shared-flow` service. This will cause the `rate-limiting` and `key-auth` plugins to execute. If they pass, the original request continues to `http://my-real-upstream.com`. If they fail, the `flow-callout` will terminate the request with a `401` error.
