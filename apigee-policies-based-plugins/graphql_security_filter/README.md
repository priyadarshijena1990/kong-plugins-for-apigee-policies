# Kong Plugin: GraphQL Security Filter

This plugin provides a basic layer of security for GraphQL endpoints by filtering requests based on operation type and blocking requests that match configurable regex patterns.

**Important**: This is a lightweight security plugin, not a full GraphQL parser or validator. It does not validate requests against a GraphQL schema.

## How it Works

The plugin inspects the raw GraphQL query string provided in the request body. It performs two main checks:

1.  **Operation Type Filtering**: It detects if the request is a `query`, `mutation`, or `subscription`. If the `allowed_operation_types` configuration is set, the plugin will block any request whose operation type is not in the allowed list.
2.  **Pattern Blocking**: It checks the query string against a list of regular expression `block_patterns`. If any pattern matches, the request is blocked. This is useful for preventing introspection queries (`__schema`, `__type`) or blocking queries that contain certain sensitive field names.

If a request is not blocked, the plugin can optionally extract the detected operation type into the `kong.ctx.shared` for use by other plugins.

## Configuration

*   **`allowed_operation_types`**: (array of strings, optional) If set, only these GraphQL operation types are allowed.
*   **`block_patterns`**: (array of strings, optional) A list of regex patterns to match against the query string. If a match is found, the request is blocked.
*   **`block_status`**: (number, default: `400`) The HTTP status code to return for a blocked request.
*   **`block_body`**: (string, default: `"Invalid GraphQL request."`) The response body for a blocked request.
*   **`extract_operation_type_to_shared_context_key`**: (string, optional) If set, the detected operation type (`query`, `mutation`, or `subscription`) will be stored in `kong.ctx.shared`.

### Example: Allow only queries and block introspection

```yaml
plugins:
- name: graphql-security-filter
  config:
    allowed_operation_types:
    - query
    block_patterns:
    - "__schema"
    - "__type"
    block_status: 403
    block_body: "Forbidden"
```
