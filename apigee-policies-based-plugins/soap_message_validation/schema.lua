local typedefs = require "kong.db.schema.typedefs"

return {
  name = "soap-message-validation",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            soap_validation_service_url = {
              type = "string",
              required = true,
              description = "The URL of the external service responsible for SOAP message validation.",
            },
          },
          {
            message_source_type = {
              type = "string",
              required = true,
              enum = { "request_body", "response_body", "shared_context" },
              description = "Specifies where to get the SOAP message content (XML string) for validation.",
            },
          },
          {
            message_source_name = {
              type = "string",
              description = "Required if `message_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the SOAP message string.",
            },
          },
          {
            xsd_source_type = {
              type = "string",
              required = true,
              enum = { "literal", "url", "shared_context" },
              description = "Specifies where to get the XSD schema definition for validation.",
            },
          },
          {
            xsd_source_name = {
              type = "string",
              description = "Required if `xsd_source_type` is 'url' or 'shared_context'. This is the URL to the XSD file or the key in `kong.ctx.shared` holding the XSD string.",
            },
          },
          {
            xsd_literal = {
              type = "string",
              description = "Required if `xsd_source_type` is 'literal'. The actual XSD schema XML string.",
            },
          },
          {
            validate_parts = {
              type = "array",
              default = {},
              elements = {
                type = "string",
                enum = { "Envelope", "Header", "Body", "Fault" },
              },
              description = "Optional: Which parts of the SOAP message to specifically validate. If empty, the entire message is validated.",
            },
          },
          {
            on_validation_failure_status = {
              type = "number",
              default = 400,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if SOAP message validation fails and `on_validation_failure_continue` is `false`.",
            },
          },
          {
            on_validation_failure_body = {
              type = "string",
              default = "SOAP message validation failed.",
              description = "The response body to return to the client if SOAP message validation fails and `on_validation_failure_continue` is `false`.",
            },
          },
          {
            on_validation_failure_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request/response processing will continue even if SOAP message validation fails. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
