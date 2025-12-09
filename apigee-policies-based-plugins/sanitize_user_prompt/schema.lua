local typedefs = require "kong.db.schema.typedefs"

return {
  name = "sanitize-user-prompt",
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
              enum = { "header", "query", "body" },
            },
          },
          {
            source_name = {
              type = "string",
              required = true,
              -- The name of the header/query param, or JSON path for body
            },
          },
          {
            destination_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "body", "shared_context" },
            },
          },
          {
            destination_name = {
              type = "string",
              required = true,
              -- The name of the header/query param/JSON path, or shared context key
            },
            },
          {
            trim_whitespace = {
              type = "boolean",
              default = true,
            },
          },
          {
            remove_html_tags = {
              type = "boolean",
              default = false,
            },
          },
          {
            max_length = {
              type = "number",
              -- Optional: truncates the prompt if it exceeds this length
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
            block_on_match = {
              type = "array",
              default = {},
              elements = {
                type = "string",
                -- Regex patterns. If any match, the request will be blocked.
              },
            },
          },
          {
            block_status = {
              type = "number",
              default = 400,
              between = { 400, 599 },
            },
          },
          {
            block_body = {
              type = "string",
              default = "Invalid input detected.",
            },
          },
        },
      },
    },
  },
}
