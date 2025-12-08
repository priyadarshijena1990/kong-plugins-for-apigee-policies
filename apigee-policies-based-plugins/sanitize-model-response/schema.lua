local typedefs = require "kong.db.schema.typedefs"

return {
  name = "sanitize-model-response",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            response_source_jsonpath = {
              type = "string",
              default = ".", -- Refers to the entire JSON body
              -- JSON path to the part of the response to sanitize.
              -- e.g., "results.0.text" for a specific text field.
            },
          },
          {
            redact_fields = {
              type = "array",
              default = {},
              elements = {
                type = "string",
                -- JSON paths to fields whose values should be redacted.
                -- e.g., "user.email", "credit_card_number"
              },
            },
          },
          {
            redaction_string = {
              type = "string",
              default = "[REDACTED]",
            },
          },
          {
            remove_fields = {
              type = "array",
              default = {},
              elements = {
                type = "string",
                -- JSON paths to fields that should be completely removed.
                -- e.g., "internal_debug_info", "raw_data"
              },
            },
          },
          {
            replacements = {
              type = "array",
              default = {},
              elements = {
                type = "record",
                fields = {
                  { pattern = { type = "string", required = true } },
                  { replacement = { type = "string", required = true } },
                },
              },
            },
          },
          {
            max_length = {
              type = "number",
              -- Optional: truncates the entire (final) response body if it exceeds this length.
            },
          },
        },
      },
    },
  },
}
