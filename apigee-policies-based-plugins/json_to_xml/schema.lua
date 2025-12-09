local typedefs = require "kong.db.schema.typedefs"

return {
  name = "json-to-xml",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            source_type = {
              type = "string",
              required = true,
              enum = { "request_body", "response_body", "shared_context" },
              description = "Specifies where to get the JSON content from for conversion.",
            },
          },
          {
            source_key = {
              type = "string",
              description = "Required if `source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the JSON content.",
            },
          },
          {
            output_type = {
              type = "string",
              required = true,
              enum = { "request_body", "response_body", "shared_context" },
              description = "Specifies where to put the converted XML content.",
            },
          },
          {
            output_key = {
              type = "string",
              description = "Required if `output_type` is `shared_context`. This is the key in `kong.ctx.shared` to store the XML content.",
            },
          },
          {
            root_element_name = {
              type = "string",
              default = "root",
              description = "The name of the root XML element.",
            },
          },
          {
            array_root_element_name = {
              type = "string",
              description = "Optional: The name of the wrapper element for arrays. If not provided, arrays will not have a root element.",
            },
          },
          {
            array_item_element_name = {
              type = "string",
              default = "item",
              description = "The name for individual elements within an array. Defaults to 'item'.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request/response processing will continue even if JSON to XML conversion fails. If `false`, the request will be terminated.",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if conversion fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "JSON to XML conversion failed.",
              description = "The response body to return to the client if conversion fails and `on_error_continue` is `false`.",
            },
          },
        },
      },
    },
  },
}
