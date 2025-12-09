local typedefs = require "kong.db.schema.typedefs"

return {
  name = "semantic-cache-populate",
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
            cache_ttl = {
              type = "number",
              required = true,
              between = { 1, 31536000 }, -- 1 second to 1 year
            },
          },
          {
            source = {
              type = "string",
              required = true,
              enum = { "response_body", "shared_context" },
            },
          },
          {
            shared_context_key = {
              type = "string",
              -- Required if source is "shared_context"
            },
          },
        },
      },
    },
  },
}
