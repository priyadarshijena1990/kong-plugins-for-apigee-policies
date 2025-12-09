local typedefs = require "kong.db.schema.typedefs"

return {
  name = "graphql-security-filter",
  priority = 1000, -- Adding priority for custom ordering
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            allowed_operation_types = {
              type = "array",
              default = {},
              elements = {
                type = "string",
                enum = { "query", "mutation", "subscription" },
              },
              description = "Optional: If set, only these GraphQL operation types are allowed. Requests with other operation types will be blocked.",
            },
          },
          {
            block_patterns = {
              type = "array",
              default = {},
              elements = {
                type = "string",
                -- Regex patterns. If any match, the request will be blocked.
              },
              description = "Optional: A list of regular expression patterns. If any pattern matches the raw GraphQL query string, the request will be blocked.",
            },
          },
          {
            block_status = {
              type = "number",
              default = 400,
              between = { 400, 599 },
              description = "The HTTP status code to return if a request is blocked by `allowed_operation_types` or `block_patterns`.",
            },
          },
          {
            block_body = {
              type = "string",
              default = "Invalid GraphQL request.",
              description = "The response body to return if a request is blocked.",
            },
          },
          {
            extract_operation_type_to_shared_context_key = {
              type = "string",
              description = "Optional: If set, the detected GraphQL operation type ('query', 'mutation', or 'subscription') will be stored in `kong.ctx.shared` under this key.",
            },
          },
        },
      },
    },
  },
}
