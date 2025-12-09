local typedefs = require "kong.db.schema.typedefs"

return {
  name = "set-integration-request",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            integration_name = {
              type = "string",
              required = true,
            },
          },
          {
            trigger_name = {
              type = "string",
              required = true,
            },
          },
          {
            parameters = {
              type = "array",
              default = {},
              elements = {
                type = "record",
                fields = {
                  {
                    name = {
                      type = "string",
                      required = true,
                    },
                  },
                  {
                    type = {
                      type = "string",
                      required = true,
                      enum = { "STRING", "INT", "BOOLEAN", "JSON" },
                    },
                  },
                  {
                    source = {
                      type = "string",
                      required = true,
                      enum = { "header", "query", "body", "literal" },
                    },
                  },
                  {
                    source_name = {
                      type = "string",
                      -- Required if source is header, query, or body
                      -- Not required if source is literal
                    },
                  },
                  {
                    value = {
                      type = "string",
                      -- Required if source is literal
                      -- Not used if source is header, query, or body
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
  },
}
