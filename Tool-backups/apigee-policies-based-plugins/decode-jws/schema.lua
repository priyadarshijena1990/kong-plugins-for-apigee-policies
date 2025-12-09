local typedefs = require "kong.db.schema.typedefs"

return {
  name = "decode-jws",
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
            jws_decode_service_url = {
              type = "string",
              required = true,
              description = "The URL of the external service responsible for JWS decoding and signature verification.",
            },
          },
          {
            jws_source_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "body", "shared_context" },
              description = "Specifies where to get the JWS string from in the incoming request.",
            },
          },
          {
            jws_source_name = {
              type = "string",
              required = true,
              description = "The name of the header/query parameter, the JSON path for a 'body' source, or the key in `kong.ctx.shared` that holds the JWS string.",
            },
          },
          {
            public_key_source_type = {
              type = "string",
              required = true,
              enum = { "literal", "shared_context" },
              description = "Specifies where to get the public key/certificate for JWS signature verification.",
            },
          },
          {
            public_key_source_name = {
              type = "string",
              description = "Required if `public_key_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the public key/certificate string.",
            },
          },
          {
            public_key_literal = {
              type = "string",
              description = "Required if `public_key_source_type` is `literal`. The actual public key/certificate string to use for verification.",
            },
          },
          {
            claims_to_extract = {
              type = "array",
              default = {},
              elements = {
                type = "record",
                fields = {
                  {
                    claim_name = {
                      type = "string",
                      required = true,
                      description = "The name of the claim (e.g., 'iss', 'aud', 'sub', or a custom claim) to extract from the JWS payload.",
                    },
                  },
                  {
                    output_key = {
                      type = "string",
                      required = true,
                      description = "The key in `kong.ctx.shared` where the extracted claim value will be stored.",
                    },
                  },
                },
              },
              description = "A list of JWS claims to extract from the verified JWS payload and store in `kong.ctx.shared`.",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if JWS decoding or verification fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "JWS decoding or verification failed.",
              description = "The response body to return to the client if JWS decoding or verification fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request processing will continue even if JWS decoding or verification fails. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
