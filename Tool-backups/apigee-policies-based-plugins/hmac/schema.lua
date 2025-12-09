local typedefs = require "kong.db.schema.typedefs"

return {
  name = "hmac",
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
            mode = {
              type = "string",
              required = true,
              enum = { "verify", "generate" },
              default = "verify",
              description = "The mode of operation for the plugin: 'verify' an incoming HMAC or 'generate' a new one.",
            },
          },
          {
            secret_source_type = {
              type = "string",
              required = true,
              enum = { "literal", "shared_context" },
              description = "Specifies where to get the shared secret key for HMAC calculation.",
            },
          },
          {
            secret_source_name = {
              type = "string",
              description = "Required if `secret_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the shared secret string.",
            },
          },
          {
            secret_literal = {
              type = "string",
              description = "Required if `secret_source_type` is `literal`. The actual shared secret string.",
            },
          },
          {
            algorithm = {
              type = "string",
              required = true,
              enum = { "HMAC-SHA1", "HMAC-SHA256", "HMAC-SHA512" },
              description = "The HMAC algorithm to use for the calculation.",
            },
          },
          {
            string_to_sign_components = {
              type = "array",
              required = true,
              elements = {
                type = "record",
                fields = {
                  {
                    component_type = {
                      type = "string",
                      required = true,
                      enum = { "method", "uri", "header", "query", "body", "literal" },
                      description = "The type of component to include in the string-to-sign.",
                    },
                  },
                  {
                    component_name = {
                      type = "string",
                      description = "Required for 'header', 'query', 'body', 'literal' types. Header name, query parameter name, JSON path for body, or the literal string value.",
                    },
                  },
                },
              },
              description = "A list defining the components that form the 'string-to-sign' in the specified order.",
            },
          },
          -- Verification-specific fields
          {
            signature_header_name = {
              type = "string",
              description = "Required for 'verify' mode. The name of the HTTP header where the client-provided HMAC signature is expected.",
            },
          },
          {
            signature_prefix = {
              type = "string",
              default = "",
              description = "Optional for 'verify' mode: A prefix to strip from the signature header value (e.g., 'HMAC ').",
            },
          },
          {
            on_verification_failure_status = {
              type = "number",
              default = 401,
              description = "For 'verify' mode: The HTTP status code to return if HMAC verification fails.",
            },
          },
          {
            on_verification_failure_body = {
              type = "string",
              default = "HMAC verification failed.",
              description = "For 'verify' mode: The response body to return if HMAC verification fails.",
            },
          },
          {
            on_verification_failure_continue = {
              type = "boolean",
              default = false,
              description = "For 'verify' mode: If `true`, continue processing even if verification fails. If `false`, terminate the request.",
            },
          },
          -- Generation-specific fields
          {
            output_destination_type = {
              type = "string",
              enum = { "header", "shared_context" },
              description = "Required for 'generate' mode: Specifies where to place the generated HMAC signature.",
            },
          },
          {
            output_destination_name = {
              type = "string",
              description = "Required for 'generate' mode: The name of the header or context key where the HMAC signature will be stored.",
            },
          },
        },
      },
    },
  },
}
