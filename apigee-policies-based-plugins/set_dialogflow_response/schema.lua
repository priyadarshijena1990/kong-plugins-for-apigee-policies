local typedefs = require "kong.db.schema.typedefs"

return {
  name = "set-dialogflow-response",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            response_source = {
              type = "string",
              required = true,
              enum = { "upstream_body", "shared_context" },
              default = "upstream_body",
            },
          },
          {
            shared_context_key = {
              type = "string",
              -- Required if response_source is "shared_context"
            },
          },
          {
            mappings = {
              type = "array",
              default = {},
              elements = {
                type = "record",
                fields = {
                  {
                    output_field = {
                      type = "string",
                      required = true,
                    },
                  },
                  {
                    dialogflow_jsonpath = {
                      type = "string",
                      required = true,
                    },
                  },
                },
              },
            },
          },
          {
            output_content_type = {
              type = "string",
              default = "application/json",
            },
          },
          {
            default_response_body = {
              type = "string",
              -- This should be a JSON string
            },
          },
        },
      },
    },
  },
}
