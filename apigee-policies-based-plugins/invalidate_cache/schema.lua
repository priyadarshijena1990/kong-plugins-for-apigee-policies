local typedefs = require "kong.db.schema.typedefs"

return {
  name = "invalidate-cache",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            purge_by_prefix = {
              type = "boolean",
              default = false,
              description = "If `true`, purges all cache entries starting with the `cache_key_prefix`. If `false`, constructs a specific key using fragments.",
            },
          },
          {
            cache_key_prefix = {
              type = "string",
              default = "",
              description = "A prefix for the cache key. Used as the full key for prefix-based purging, or prepended to the generated key for single-key invalidation.",
            },
          },
          {
            cache_key_fragments = {
              type = "array",
              default = {},
              elements = {
                type = "string",
                description = "A list of references (e.g., `request.uri`, `shared_context.user_id`) to build the cache key. Ignored if `purge_by_prefix` is true.",
              },
            },
          },
          {
            on_invalidation_success_status = {
              type = "number",
              default = 200,
              description = "HTTP status code to return if invalidation is successful and `continue_on_invalidation` is `false`.",
            },
          },
          {
            on_invalidation_success_body = {
              type = "string",
              default = "Cache entry/entries invalidated.",
              description = "Response body to return if invalidation is successful and `continue_on_invalidation` is `false`.",
            },
          },
          {
            on_invalidation_failure_status = {
              type = "number",
              default = 500,
              description = "HTTP status code to return if invalidation fails and `continue_on_invalidation` is `false`.",
            },
          },
          {
            on_invalidation_failure_body = {
              type = "string",
              default = "Cache invalidation failed.",
              description = "Response body to return if invalidation fails and `continue_on_invalidation` is `false`.",
            },
          },
          {
            continue_on_invalidation = {
              type = "boolean",
              default = true,
              description = "If `true`, request processing will continue after invalidation attempt. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
