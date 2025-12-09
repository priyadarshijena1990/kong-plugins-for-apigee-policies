# Regular Expression Protection Plugin (regular-expression-protection)

The Regular Expression Protection plugin inspects incoming requests for content that matches a list of regular expressions. It is designed to replicate the core functionality of Apigee's Regular Expression Protection policy, helping to guard against common content-level threats like SQL injection or code injection attacks.

## How it Works

The plugin operates in the `access` phase, running with a high priority to check requests before they are processed by other plugins or forwarded to the upstream service.

You configure the plugin to inspect a specific part of the request (e.g., a header, query parameter, or the request body) and provide a list of "deny" patterns. If any of these patterns match the input, the request is immediately blocked with a configurable status code and message.

Optionally, you can also provide a list of "allow" patterns. If `allow_patterns` are defined, the input must match at least one of them to be permitted, otherwise it will be blocked.

## Configuration

The plugin can be configured with the following parameters:

| Parameter         | Required | Description                                                                                             |
| ----------------- | -------- | ------------------------------------------------------------------------------------------------------- |
| `input_source`    | **Yes**  | The part of the request to inspect. Can be `request_body`, `header`, `query`, or `uri_path`.              |
| `input_name`      | For some | Required if `input_source` is `header` or `query`. Specifies the name of the header or query parameter.   |
| `deny_patterns`   | **Yes**  | An array of PCRE-compatible regular expression strings. If any pattern matches the input, the request is blocked. |
| `allow_patterns`  | No       | An array of PCRE-compatible regular expression strings. If defined, the input *must* match at least one of these patterns to proceed. |
| `block_status`    | No       | The HTTP status code to return when a request is blocked. Defaults to `403`.                            |
| `block_message`   | No       | The JSON message to return in the response body when a request is blocked. Defaults to `Forbidden`.     |

## Usage Example

### Scenario

Protect a search endpoint (`/products/search`) from basic SQL injection attempts in the `q` query parameter.

### Plugin Configuration

```yaml
plugins:
  - name: regular-expression-protection
    config:
      input_source: "query"
      input_name: "q"
      deny_patterns:
        - "(?i)(union|select|--|;)" # Deny common SQL keywords/characters
        - "[<>]" # Deny HTML tags
      block_status: 400
      block_message: "Invalid characters detected in search query."
```

### Blocked Request

An attacker sends a malicious request:
```http
GET /products/search?q=shoes%27%3B%20DROP%20TABLE%20users%3B -- HTTP/1.1
Host: kong-gateway.com
```

### Result

The `regular-expression-protection` plugin inspects the `q` parameter (`shoes'; DROP TABLE users; --`). The pattern `(;)` matches. The plugin immediately halts the request and returns the following response to the client:

```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{"message":"Invalid characters detected in search query."}
```