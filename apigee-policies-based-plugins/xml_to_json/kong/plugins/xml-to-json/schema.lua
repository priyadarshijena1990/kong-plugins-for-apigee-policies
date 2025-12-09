local typedefs = require "kong.db.schema.typedefs"

return {
  name = "xml-to-json",
  fields = {
    { consumer = typedefs.consumer },
    { route = typedefs.route },
    { service = typedefs.service },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { source = {
              type = "string",
              default = "response",
              enum = { "request", "response" },
              help = "Specifies whether to convert XML in the request or response body.",
            },
          },
          { strip_namespaces = {
              type = "boolean",
              default = true,
              help = "When true, removes XML namespaces during conversion.",
            },
          },
          { attribute_prefix = {
              type = "string",
              default = "@",
              help = "Prefix for XML attributes when converted to JSON keys.",
            },
          },
          { text_node_name = {
              type = "string",
              default = "#text",
              help = "Key name for XML text content within JSON objects.",
            },
          },
          { pretty_print = {
              type = "boolean",
              default = false,
              help = "When true, the output JSON will be pretty-printed.",
            },
          },
          { content_type = {
              type = "string",
              default = "application/json",
              help = "The Content-Type header to set for the transformed body.",
            },
          },
          { remove_xml_declaration = {
              type = "boolean",
              default = false,
              help = "When true, removes the XML declaration (e.g., <?xml version='1.0'?>) from the input before parsing. Note: This may not be fully effective if `lua-xml` implicitly handles it.",
            },
          },
          { arrays_key_ending = {
              type = "string",
              default = "",
              help = "If an XML element's name ends with this string, its children will always be treated as a JSON array. Example: '_list'",
            },
          },
          { arrays_key_ending_strip = {
              type = "boolean",
              default = false,
              help = "If 'arrays_key_ending' is used, this option strips the ending from the key name in the JSON output.",
            },
          },
        },
      },
    },
  },
}