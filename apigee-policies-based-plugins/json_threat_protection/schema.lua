local typedefs = require "kong.db.schema.typedefs"

return {
  name = "json-threat-protection",
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
              enum = { "request_body", "shared_context" },
              description = "Specifies where to get the JSON content from for threat protection.",
            },
          },
          {
            source_name = {
              type = "string",
              description = "Required if `source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the JSON content.",
            },
          },
          {
            max_array_elements = {
              type = "number",
              between = { 0, 10000 }, -- Reasonable upper limit
              description = "Optional: Maximum number of elements allowed in any JSON array. Set to 0 for unlimited.",
            },
          },
          {
            max_container_depth = {
              type = "number",
              between = { 0, 100 }, -- Reasonable upper limit
              description = "Optional: Maximum nesting depth of JSON objects and arrays. Set to 0 for unlimited.",
            },
          },
          {
            max_object_entry_count = {
              type = "number",
              between = { 0, 10000 }, -- Reasonable upper limit
              description = "Optional: Maximum number of properties allowed in any JSON object. Set to 0 for unlimited.",
            },
          },
          {
            max_object_entry_name_length = {
              type = "number",
              between = { 0, 1000 }, -- Reasonable upper limit
              description = "Optional: Maximum length of any JSON object property name. Set to 0 for unlimited.",
            },
          },
          {
            max_string_value_length = {
              type = "number",
              between = { 0, 1000000 }, -- Reasonable upper limit (1MB string)
              description = "Optional: Maximum length of any string value within the JSON. Set to 0 for unlimited.",
            },
          },
          {
            on_violation_status = {
              type = "number",
              default = 400,
              between = { 400, 599 },
              description = "The HTTP status code to return if a JSON threat protection violation is detected and `on_violation_continue` is `false`.",
            },
          },
          {
            on_violation_body = {
              type = "string",
              default = "JSON threat protection violation.",
              description = "The response body to return if a JSON threat protection violation is detected and `on_violation_continue` is `false`.",
            },
          },
          {
            on_violation_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request processing will continue even if a JSON threat protection violation is detected. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
