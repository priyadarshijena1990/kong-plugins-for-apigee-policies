local typedefs = require "kong.db.schema.typedefs"

return {
  name = "decode-jwt",
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
            jwt_source_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "body", "shared_context" },
              description = "Specifies where to get the JWT string from in the incoming request.",
            },
          },
          {
            jwt_source_name = {
              type = "string",
              required = true,
              description = "The name of the header/query parameter, the JSON path for a 'body' source, or the key in `kong.ctx.shared` that holds the JWT string.",
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
                      description = "The name of the claim (e.g., 'iss', 'aud', 'sub', or a custom claim) to extract from the JWT payload.",
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
              description = "A list of JWT claims to extract from the decoded payload and store in `kong.ctx.shared`.",
            },
          },
          {
            store_all_claims_in_shared_context_key = {
              type = "string",
              description = "Optional: If set, the entire decoded JWT payload (as a Lua table) will be stored in `kong.ctx.shared` under this key.",
            },
          },
          {
            store_header_to_shared_context_key = {
              type = "string",
              description = "Optional: If set, the entire decoded JWT header (as a Lua table) will be stored in `kong.ctx.shared` under this key.",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 400,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if JWT decoding fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "JWT decoding failed.",
              description = "The response body to return to the client if JWT decoding fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request processing will continue even if JWT decoding fails. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
