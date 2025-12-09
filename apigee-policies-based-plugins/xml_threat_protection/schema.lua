local typedefs = require "kong.db.schema.typedefs"

return {
  name = "xml-threat-protection",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            xml_threat_protection_service_url = {
              type = "string",
              required = true,
              description = "The URL of the external service responsible for XML threat protection.",
            },
          },
          {
            message_source_type = {
              type = "string",
              required = true,
              enum = { "request_body", "shared_context" },
              description = "Specifies where to get the XML message content (XML string) for threat protection.",
            },
          },
          {
            message_source_name = {
              type = "string",
              description = "Required if `message_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the XML message string.",
            },
          },
          {
            max_element_depth = {
              type = "number",
              between = { 0, 100 }, -- Reasonable upper limit
              description = "Optional: Maximum nesting depth of XML elements. Set to 0 for unlimited.",
            },
          },
          {
            max_element_count = {
              type = "number",
              between = { 0, 10000 }, -- Reasonable upper limit
              description = "Optional: Maximum number of XML elements allowed in the message. Set to 0 for unlimited.",
            },
          },
          {
            max_attribute_count = {
              type = "number",
              between = { 0, 1000 }, -- Reasonable upper limit
              description = "Optional: Maximum number of attributes allowed per XML element. Set to 0 for unlimited.",
            },
          },
          {
            max_attribute_name_length = {
              type = "number",
              between = { 0, 1000 }, -- Reasonable upper limit
              description = "Optional: Maximum length of any XML attribute name. Set to 0 for unlimited.",
            },
          },
          {
            max_attribute_value_length = {
              type = "number",
              between = { 0, 1000000 }, -- Reasonable upper limit (1MB string)
              description = "Optional: Maximum length of any XML attribute value. Set to 0 for unlimited.",
            },
          },
          {
            max_entity_expansion = {
              type = "number",
              between = { 0, 1000 }, -- Reasonable upper limit for entity expansions
              description = "Optional: Maximum number of entity expansions allowed (to mitigate XML bombs). Set to 0 for unlimited.",
            },
          },
          {
            on_violation_status = {
              type = "number",
              default = 400,
              between = { 400, 599 },
              description = "The HTTP status code to return if an XML threat protection violation is detected and `on_violation_continue` is `false`.",
            },
          },
          {
            on_violation_body = {
              type = "string",
              default = "XML threat protection violation.",
              description = "The response body to return if an XML threat protection violation is detected and `on_violation_continue` is `false`.",
            },
          },
          {
            on_violation_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request processing will continue even if an XML threat protection violation is detected. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
