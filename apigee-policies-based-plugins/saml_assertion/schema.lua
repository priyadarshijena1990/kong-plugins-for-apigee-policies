local typedefs = require "kong.db.schema.typedefs"

return {
  name = "saml-assertion",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            saml_service_url = {
              type = "string",
              required = true,
              description = "The URL of the external service responsible for SAML assertion generation or verification.",
            },
          },
          {
            operation_type = {
              type = "string",
              required = true,
              enum = { "generate", "verify" },
              description = "Specifies whether to generate a SAML assertion or verify an incoming SAML assertion.",
            },
          },
          -- Configuration for 'generate' operation
          {
            saml_payload_source_type = {
              type = "string",
              enum = { "header", "query", "body", "shared_context", "literal" },
              description = "Required for 'generate' operation: Specifies where to get the data that will form the content of the SAML assertion payload.",
            },
          },
          {
            saml_payload_source_name = {
              type = "string",
              description = "Required for 'generate' operation: The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `saml_payload_source_type` is 'literal'.",
            },
          },
          {
            signing_key_source_type = {
              type = "string",
              enum = { "literal", "shared_context" },
              description = "Required for 'generate' operation: Specifies where to get the private key for signing the SAML assertion.",
            },
          },
          {
            signing_key_source_name = {
              type = "string",
              description = "Required for 'generate' operation: The key in `kong.ctx.shared` that holds the private key string.",
            },
          },
          {
            signing_key_literal = {
              type = "string",
              description = "Required for 'generate' operation: The actual private key string.",
            },
          },
          {
            output_destination_type = {
              type = "string",
              enum = { "header", "query", "body", "shared_context" },
              description = "Required for 'generate' operation: Specifies where to place the generated SAML assertion XML string.",
            },
          },
          {
            output_destination_name = {
              type = "string",
              description = "Required for 'generate' operation: The name of the header/query parameter, the JSON path for a 'body' destination, or the key in `kong.ctx.shared` where the SAML assertion will be stored.",
            },
          },
          -- Configuration for 'verify' operation
          {
            saml_assertion_source_type = {
              type = "string",
              enum = { "header", "query", "body", "shared_context" },
              description = "Required for 'verify' operation: Specifies where to get the SAML assertion XML string to be verified.",
            },
          },
          {
            saml_assertion_source_name = {
              type = "string",
              description = "Required for 'verify' operation: The name of the header/query parameter, the JSON path for a 'body' source, or the key in `kong.ctx.shared` that holds the SAML assertion string.",
            },
          },
          {
            verification_key_source_type = {
              type = "string",
              enum = { "literal", "shared_context" },
              description = "Required for 'verify' operation: Specifies where to get the public key/certificate for verifying the SAML assertion.",
            },
          },
          {
            verification_key_source_name = {
              type = "string",
              description = "Required for 'verify' operation: The key in `kong.ctx.shared` that holds the public key/certificate string.",
            },
          },
          {
            verification_key_literal = {
              type = "string",
              description = "Required for 'verify' operation: The actual public key/certificate string to use for verification.",
            },
          },
          {
            extract_claims = {
              type = "array",
              default = {},
              elements = {
                type = "record",
                fields = {
                  {
                    attribute_name = {
                      type = "string",
                      required = true,
                      description = "The name of the SAML attribute (e.g., 'urn:oid:0.9.2342.19200300.100.1.1' for uid, or a custom attribute) to extract.",
                    },
                  },
                  {
                    output_key = {
                      type = "string",
                      required = true,
                      description = "The key in `kong.ctx.shared` where the extracted SAML attribute value will be stored.",
                    },
                  },
                },
              },
              description = "Optional, for 'verify' operation: A list of SAML attributes to extract from the verified assertion and store in `kong.ctx.shared`.",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if the SAML operation fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "SAML operation failed.",
              description = "The response body to return to the client if the SAML operation fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request processing will continue even if the SAML operation fails. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
