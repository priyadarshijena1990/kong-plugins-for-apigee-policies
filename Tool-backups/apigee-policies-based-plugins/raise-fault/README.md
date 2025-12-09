# Raise Fault Plugin (raise-fault)

The Raise Fault plugin terminates the current request flow and returns a custom response to the client. It is designed to replicate the functionality of Apigee's Raise Fault policy, providing a clear and explicit way to handle error conditions or other logic branches that require an immediate, custom response.

This plugin is often used in combination with the `assert-condition` plugin. For example, `assert-condition` can check for an error state, and if it's `true`, the request flow continues to the `raise-fault` plugin to construct and send the error response.

## How it Works

The plugin operates in the `access` phase with a high priority. When it executes, it immediately stops further processing of the request (including preventing it from reaching the upstream service) and sends a response directly to the client based on its configuration.

## Configuration

The plugin can be configured with the following parameters:

| Parameter      | Required | Description                                                                                                                              |
| -------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `status_code`  | **Yes**  | The HTTP status code to return (e.g., `401`, `503`). Must be between 400 and 599.                                                         |
| `fault_body`   | No       | The raw string to be used as the response body. This can be a JSON string, an XML document, or plain text.                                |
| `content_type` | No       | The `Content-Type` of the response. Defaults to `application/json`. This is overridden if `Content-Type` is set in the `headers` map.      |
| `headers`      | No       | A map of custom headers to add to the response. For example: `{"X-Error-Code": "E1234", "Cache-Control": "no-cache"}`.                    |

## Usage Example

### Scenario

A request is missing a required API key. An earlier authentication plugin has added `user_authenticated: false` to the shared context. We use `assert-condition` to check this and, if false, let the request proceed to a `raise-fault` plugin instance on the same route.

### Plugin Configuration

This configuration would be applied to a route or service to be triggered when needed.

```yaml
plugins:
  - name: raise-fault
    config:
      status_code: 401
      content_type: "application/json; charset=utf-8"
      fault_body: '{"error": "Authentication Failed", "message": "Valid API Key is required."}'
      headers:
        X-Error-Identifier: "AUTH-001"
```

### Result

When this plugin executes, the client immediately receives the following response, and the request goes no further:

```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json; charset=utf-8
X-Error-Identifier: AUTH-001

{"error": "Authentication Failed", "message": "Valid API Key is required."}
```