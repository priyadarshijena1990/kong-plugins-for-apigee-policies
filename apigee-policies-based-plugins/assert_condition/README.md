# Assert Condition Plugin (assert-condition)

The Assert Condition plugin evaluates a Lua expression and takes a predefined action based on whether the expression evaluates to `true` or `false`. It is designed to replicate the conditional flow control capabilities often found in Apigee policies.

This plugin is useful for implementing custom logic to validate requests, check for specific states, or enforce business rules before allowing a request to proceed to the upstream service.

## How it Works

The plugin operates in the `access` phase. It takes a `condition` parameter, which is a Lua expression string. This expression is evaluated at runtime.

*   If the `condition` evaluates to `true`, the request proceeds normally.
*   If the `condition` evaluates to `false` (or `nil`), the plugin takes the action specified by `on_false_action`.

The `condition` expression can leverage any available Kong variables (e.g., `kong.request.get_header()`, `kong.request.get_query()`, `kong.request.get_path()`) and values stored in `kong.ctx.shared`.

## Configuration

The plugin can be configured with the following parameters:

| Parameter           | Required | Description                                                                                                             |
| ------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------- |
| `condition`         | **Yes**  | A Lua expression string that evaluates to `true` or `false`.                                                            |
| `on_false_action`   | **Yes**  | The action to take if the `condition` evaluates to `false`. Can be `abort` (terminate request) or `continue` (proceed). |
| `abort_status`      | No       | The HTTP status code to return if `on_false_action` is `abort`. Defaults to `400`.                                      |
| `abort_message`     | No       | The response body message to return if `on_false_action` is `abort`. Defaults to `Condition not met.`.                  |
| `on_error_continue` | No       | If `true`, continues processing even if there's an error evaluating the `condition` expression. Defaults to `false`.    |

## Usage Example

### Scenario 1: Block requests without a specific header

**Plugin Configuration:**
```yaml
plugins:
  - name: assert-condition
    config:
      condition: "kong.request.get_header('X-Required-Header') ~= nil"
      on_false_action: "abort"
      abort_status: 403
      abort_message: "Missing required header: X-Required-Header"
```

### Scenario 2: Allow requests only from a specific IP address

**Plugin Configuration:**
```yaml
plugins:
  - name: assert-condition
    config:
      condition: "kong.client.get_ip() == '192.168.1.100'"
      on_false_action: "abort"
      abort_status: 403
      abort_message: "Access denied from this IP address."
```

### Scenario 3: Check a value from shared context

**Plugin Configuration:**
```yaml
plugins:
  - name: assert-condition
    config:
      condition: "kong.ctx.shared.user_role == 'admin'"
      on_false_action: "abort"
      abort_status: 401
      abort_message: "Unauthorized: Admin role required."
```