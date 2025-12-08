local typedefs = require "kong.db.schema.typedefs"

return {
  name = "delete-oauth-v2-info",
  priority = 1000,
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            token_source_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "body", "shared_context" },
              description = "Specifies where to get the OAuth 2.0 access token string from.",
            },
          },
          {
            token_source_name = {
              type = "string",
              required = true,
              description = "The name of the header/query parameter, the JSON path for a 'body' source, or the key in `kong.ctx.shared` that holds the token string.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request processing will continue even if the token cannot be deleted. If `false`, the request may be terminated on failure.",
            },
          },
        },
      },
    },
  },
}
