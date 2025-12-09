local typedefs = require "kong.db.schema.typedefs"

return {
  name = "generate-jws",
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
            payload_source_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "body", "shared_context", "literal" },
              description = "Specifies where to get the payload content that will be signed.",
            },
          },
          {
            payload_source_name = {
              type = "string",
              description = "The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `payload_source_type` is 'literal'.",
            },
          },
          {
            private_key_source_type = {
              type = "string",
              required = true,
              enum = { "literal", "shared_context" },
              description = "Specifies where to get the private key for JWS signing.",
            },
          },
          {
            private_key_source_name = {
              type = "string",
              description = "Required if `private_key_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the private key string.",
            },
          },
          {
            private_key_literal = {
              type = "string",
              description = "Required if `private_key_source_type` is `literal`. The actual private key string to use for signing.",
            },
          },
          {
            algorithm = {
              type = "string",
              required = true,
              enum = { "HS256", "RS256", "ES256" },
              description = "The JWS signing algorithm to use.",
            },
          },
          {
            jws_header_parameters = {
              type = "map",
              default = {},
              description = "Optional: Custom JWS header parameters (e.g., 'kid', 'typ').",
            },
          },
          {
            output_destination_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "body", "shared_context" },
              description = "Specifies where to place the generated JWS string.",
            },
          },
          {
            output_destination_name = {
              type = "string",
              required = true,
              description = "The name of the header/query parameter, the JSON path for a 'body' destination, or the key in `kong.ctx.shared` where the JWS string will be stored.",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if JWS generation or signing fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "JWS generation failed.",
              description = "The response body to return to the client if JWS generation or signing fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request processing will continue even if JWS generation or signing fails. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
