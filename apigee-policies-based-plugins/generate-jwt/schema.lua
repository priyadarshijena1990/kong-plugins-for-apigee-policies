local typedefs = require "kong.db.schema.typedefs"

return {
  name = "generate-jwt",
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
            algorithm = {
              type = "string",
              required = true,
              enum = { "HS256", "RS256", "ES256" },
              description = "The JWT signing algorithm to use.",
            },
          },
          {
            secret_source_type = {
              type = "string",
              enum = { "literal", "shared_context" },
              description = "Required if algorithm is HS256: Specifies where to get the secret key for signing.",
            },
          },
          {
            secret_source_name = {
              type = "string",
              description = "Required if `secret_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the secret key string.",
            },
          },
          {
            secret_literal = {
              type = "string",
              description = "Required if `secret_source_type` is `literal`. The actual secret key string.",
            },
          },
          {
            private_key_source_type = {
              type = "string",
              enum = { "literal", "shared_context" },
              description = "Required if algorithm is RS256 or ES256: Specifies where to get the private key for signing.",
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
              description = "Required if `private_key_source_type` is `literal`. The actual private key string.",
            },
          },
          {
            subject_source_type = {
              type = "string",
              enum = { "header", "query", "body", "shared_context", "literal" },
              description = "Optional: Specifies where to get the value for the 'sub' (Subject) claim.",
            },
          },
          {
            subject_source_name = {
              type = "string",
              description = "The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `subject_source_type` is 'literal'.",
            },
          },
          {
            issuer_source_type = {
              type = "string",
              enum = { "header", "query", "body", "shared_context", "literal" },
              description = "Optional: Specifies where to get the value for the 'iss' (Issuer) claim.",
            },
          },
          {
            issuer_source_name = {
              type = "string",
              description = "The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `issuer_source_type` is 'literal'.",
            },
          },
          {
            audience_source_type = {
              type = "string",
              enum = { "header", "query", "body", "shared_context", "literal" },
              description = "Optional: Specifies where to get the value for the 'aud' (Audience) claim.",
            },
          },
          {
            audience_source_name = {
              type = "string",
              description = "The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `audience_source_type` is 'literal'.",
            },
          },
          {
            expires_in_seconds = {
              type = "number",
              description = "Optional: The time in seconds after which the JWT will expire. If omitted, the JWT might not have an 'exp' claim or will rely on the external service's default.",
            },
          },
          {
            jws_header_parameters = {
              type = "map",
              default = {},
              description = "Optional: Custom JWS header parameters (e.g., 'kid', 'typ'). These will be merged with the 'alg' header.",
            },
          },
          {
            additional_claims = {
              type = "array",
              default = {},
              elements = {
                type = "record",
                fields = {
                  {
                    claim_name = {
                      type = "string",
                      required = true,
                      description = "The name of the custom claim to include in the JWT payload.",
                    },
                  },
                  {
                    claim_value_source_type = {
                      type = "string",
                      required = true,
                      enum = { "header", "query", "body", "shared_context", "literal" },
                      description = "Specifies where to get the value for this custom claim.",
                    },
                  },
                  {
                    claim_value_source_name = {
                      type = "string",
                      description = "The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `claim_value_source_type` is 'literal'.",
                    },
                  },
                },
              },
              description = "A list of additional custom claims to include in the JWT payload.",
            },
          },
          {
            output_destination_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "body", "shared_context" },
              description = "Specifies where to place the generated JWT string.",
            },
          },
          {
            output_destination_name = {
              type = "string",
              required = true,
              description = "The name of the header/query parameter, the JSON path for a 'body' destination, or the key in `kong.ctx.shared` where the JWT string will be stored.",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if JWT generation or signing fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "JWT generation failed.",
              description = "The response body to return to the client if JWT generation or signing fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request processing will continue even if JWT generation or signing fails. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
