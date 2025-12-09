local typedefs = require "kong.db.schema.typedefs"

return {
  name = "concurrent-rate-limit",
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
            rate = {
              type = "number",
              required = true,
              between = { 1, 1000000 }, -- Reasonable range for concurrent requests
              description = "The maximum number of concurrent requests allowed.",
            },
          },
          {
            policy = {
              type = "string",
              enum = { "local", "cluster" },
              default = "local",
              description = "The policy to use for storing the counter. 'local' uses a shared memory dictionary on each node (fast, but not shared across a cluster). 'cluster' uses the Kong database to share the counter across all nodes (slower, but cluster-aware).",
            },
          },
          {
            counter_key_source_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "path", "shared_context" },
              description = "Specifies where to get the identifier that defines the scope of the concurrent limit.",
            },
          },
          {
            counter_key_source_name = {
              type = "string",
              required = true,
              description = "The name of the header/query parameter, the path for 'path' type (e.g., '/users' or '.' for full URI), or the key in `kong.ctx.shared` that holds the value for the counter key.",
            },
          },
          {
            on_limit_exceeded_status = {
              type = "number",
              default = 429,
              between = { 400, 599 },
              description = "The HTTP status code to return when the concurrent limit is exceeded.",
            },
          },
          {
            on_limit_exceeded_body = {
              type = "string",
              default = "Too Many Concurrent Requests.",
              description = "The response body to return when the concurrent limit is exceeded.",
            },
          },
        },
      },
    },
  },
}
