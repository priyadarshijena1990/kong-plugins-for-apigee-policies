local typedefs = require "kong.db.schema.typedefs"

return {
  name = "xml-to-json",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            xml_to_json_service_url = {
              type = "string",
              required = true,
              description = "The URL of the external service responsible for XML to JSON conversion.",
            },
          },
          {
            message_source_type = {
              type = "string",
              required = true,
              enum = { "request_body", "response_body", "shared_context" },
              description = "Specifies where to get the XML content (XML string) for conversion.",
            },
          },
          {
            message_source_name = {
              type = "string",
              description = "Required if `message_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the XML message string.",
            },
          },
          {
            output_destination_type = {
              type = "string",
              required = true,
              enum = { "request_body", "response_body", "shared_context" },
              description = "Specifies where to place the converted JSON content.",
            },
          },
          {
            output_destination_name = {
              type = "string",
              description = "Required if `output_destination_type` is `shared_context`. This is the key in `kong.ctx.shared` where the converted JSON content will be stored.",
            },
          },
          {
            conversion_options = {
              type = "map",
              default = {},
              description = "Optional: A map of conversion options to pass to the external service (e.g., 'omit_xml_declaration', 'strip_comments', 'format', 'indent'). These options depend on the external service's capabilities.",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if XML to JSON conversion fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "XML to JSON conversion failed.",
              description = "The response body to return to the client if XML to JSON conversion fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request/response processing will continue even if XML to JSON conversion fails. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
