local typedefs = require "kong.db.schema.typedefs"

return {
  name = "xsltransform",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            xsl_file = {
              type = "string",
              required = true,
              description = "The name of the XSLT stylesheet file located in the plugin's 'xsl' directory (e.g., 'default.xsl').",
            },
          },
          {
            xml_source = {
              type = "string",
              required = true,
              enum = { "request_body", "response_body", "shared_context" },
              description = "Specifies the source of the XML to be transformed.",
            },
          },
          {
            xml_source_name = {
              type = "string",
              description = "Required if 'xml_source' is 'shared_context'. The key in `kong.ctx.shared` where the XML string is stored.",
            },
          },
          {
            output_destination = {
              type = "string",
              required = true,
              enum = { "replace_request_body", "replace_response_body", "shared_context" },
              description = "Specifies where to place the transformed output.",
            },
          },
          {
            output_destination_name = {
              type = "string",
              description = "Required if 'output_destination' is 'shared_context'. The key in `kong.ctx.shared` where the transformed output will be stored.",
            },
          },
          {
            content_type = {
              type = "string",
              default = "application/xml",
              description = "The 'Content-Type' header to set on the request/response when the body is replaced.",
            },
          },
          {
            parameters = {
              type = "array",
              description = "An array of parameters to pass to the XSLT stylesheet.",
              elements = {
                type = "record",
                fields = {
                  { name = { type = "string", required = true, description = "The name of the parameter in the XSLT." } },
                  { value_from = { type = "string", required = true, enum = { "literal", "shared_context" }, description = "Where to source the parameter's value from." } },
                  { value = { type = "string", required = true, description = "The literal value or the key in `kong.ctx.shared` for the parameter." } },
                }
              }
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If true, continues processing the request even if the transformation fails. If false, terminates the request with an error.",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              description = "The HTTP status code to return if transformation fails and on_error_continue is false.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "XSL Transformation failed.",
              description = "The response body to return if transformation fails and on_error_continue is false.",
            },
          },
        },
      },
    },
  },
}