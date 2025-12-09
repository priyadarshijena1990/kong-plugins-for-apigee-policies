local typedefs = require "kong.db.schema.typedefs"

return {
  name = "semantic-cache-lookup",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            cache_key_prefix = {
              type = "string",
              default = "",
            },
          },
          {
            cache_key_fragments = {
              type = "array",
              default = {},
              elements = {
                type = "string",
                -- Example: "request.uri", "request.headers.Accept", "request.query_param.id", "shared_context.my_data"
              },
            },
          },
          {
            assign_to_shared_context_key = {
              type = "string",
              -- If set, the cached content will be stored here in kong.ctx.shared
            },
          },
          {
            respond_from_cache_on_hit = {
              type = "boolean",
              default = true,
            },
          },
          {
            cache_hit_status = {
              type = "number",
              default = 200,
              between = { 200, 599 },
            },
          },
          {
            cache_hit_headers = {
              type = "map",
              default = {},
            },
          },
          {
            cache_hit_header_name = {
              type = "string",
              default = "X-Cache-Status",
            },
          },
        },
      },
    },
  },
}
