# GraphQL Kong Plugin (Basic)

## Purpose

The `GraphQL` plugin for Kong Gateway provides basic security and enforcement capabilities for GraphQL requests. While a full-featured GraphQL API Gateway would typically offer schema validation, field-level security, and query depth analysis, this plugin focuses on fundamental controls based on the raw GraphQL query string.

It allows you to restrict allowed GraphQL operation types (query, mutation, subscription) and block requests containing specific malicious patterns, providing an initial layer of defense for your GraphQL endpoints.

## Abilities and Features

*   **GraphQL Query Extraction**: Automatically extracts the GraphQL query string from the client's request body (supports standard JSON format `{"query": "..."}` or raw GraphQL in the body).
*   **Operation Type Detection**: Detects the primary GraphQL `operation_type` (e.g., `query`, `mutation`, `subscription`) using basic keyword matching.
*   **Operation Type Enforcement**: Configure a list of `allowed_operation_types`. Requests with operation types not in this list will be blocked.
*   **Pattern Blocking**: Define `block_patterns` (regular expressions) that, if matched within the GraphQL query string, will result in the request being blocked.
*   **Shared Context Integration**: Optionally store the detected `operation_type` in `kong.ctx.shared` for use by other plugins or custom logic (e.g., for conditional routing or logging).
*   **Configurable Block Response**: Customize the `block_status` code and `block_body` content for blocked requests.

<h2>Limitations</h2>

This is a *basic* GraphQL policy and intentionally does *not* provide the following advanced features, which would typically require a full GraphQL parser and schema introspection:
*   **GraphQL Schema Validation**: No validation against your GraphQL schema.
*   **Field-Level Security/Authorization**: Cannot restrict access to specific fields within a query.
*   **Query Depth Analysis**: Cannot limit the nesting depth of GraphQL queries.
*   **Query Complexity Analysis**: Cannot analyze or limit the computational complexity of queries.
*   **GraphQL-specific Caching**: Does not provide intelligent GraphQL caching.

For these advanced features, consider using a dedicated GraphQL API gateway solution or a more sophisticated Kong plugin that integrates a full GraphQL parser.

<h2>Use Cases</h2>

*   **Basic Security Baseline**: Implement a first line of defense against common GraphQL attacks by blocking known malicious patterns or preventing unauthorized operation types (e.g., disallow mutations for public APIs).
*   **Operation Type-Based Routing**: Use the extracted `operation_type` in `kong.ctx.shared` to route `queries` to read-replica databases and `mutations` to write-enabled instances.
*   **API Governance**: Enforce basic API design principles by restricting usage to only certain types of operations.
*   **Traffic Monitoring**: Log the operation type for analytics or auditing purposes.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`allowed_operation_types`**: (array of strings, optional, enum: `query`, `mutation`, `subscription`, default: `{}`) If provided, only requests with these GraphQL operation types will be permitted. Requests with other types (or undetected types) will be blocked.
*   **`block_patterns`**: (array of strings, optional, default: `{}`) A list of regular expression patterns. If any pattern matches the raw GraphQL query string, the request will be blocked. Useful for preventing known attack vectors (e.g., deeply nested aliases, specific directives).
*   **`block_status`**: (number, default: `400`, between: `400` and `599`) The HTTP status code to return when a request is blocked.
*   **`block_body`**: (string, default: `"Invalid GraphQL request."`) The response body to return when a request is blocked.
*   **`extract_operation_type_to_shared_context_key`**: (string, optional) If set, the detected GraphQL operation type (`query`, `mutation`, or `subscription`) will be stored in `kong.ctx.shared` under this key.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to only allow queries and mutations, blocking common attack patterns:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=graphql" \
    --data "config.allowed_operation_types=query" \
    --data "config.allowed_operation_types=mutation" \
    --data "config.block_patterns.1=(__schema)" \
    --data "config.block_patterns.2=(__type)" \
    --data "config.block_status=403" \
    --data "config.block_body=GraphQL introspection or invalid operation not allowed." \
    --data "config.extract_operation_type_to_shared_context_key=graphql_op_type"
```

**Enable on a Route to block requests containing a specific sensitive field name:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=graphql" \
    --data "config.block_patterns.1=(creditCardNumber)" \
    --data "config.block_status=400" \
    --data "config.block_body=Sensitive field access not permitted."
```

<h2>Accessing Information</h2>

If `extract_operation_type_to_shared_context_key` was configured, the detected operation type is available in `kong.ctx.shared`.

**Example (in a custom Lua plugin or `lua_condition`):**

```lua
local op_type = kong.ctx.shared.graphql_op_type

if op_type == "mutation" then
    kong.log.notice("Processing a GraphQL mutation.")
    -- Apply mutation-specific logic
elseif op_type == "query" then
    kong.log.notice("Processing a GraphQL query.")
end
```
