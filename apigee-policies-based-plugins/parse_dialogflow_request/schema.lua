local typedefs = require "kong.db.schema.typedefs"

return {
  name = "parse-dialogflow-request",
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
              default = "request_body",
              description = "Specifies where to get the raw Dialogflow request JSON from.",
            },
          },
          {
            source_key = {
              type = "string",
              description = "Required if `source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the Dialogflow request JSON.",
            },
          },
          {
            mappings = {
              type = "array",
              required = true,
              elements = {
                type = "record",
                fields = {
                  {
                    output_key = {
                      type = "string",
                      required = true,
                      description = "The key in `kong.ctx.shared` where the extracted value will be stored.",
                    },
                  },
                  {
                    dialogflow_jsonpath = {
                      type = "string",
                      required = true,
                      description = "A dot-notation JSONPath (e.g., `queryResult.intent.displayName`) to extract the value from the parsed Dialogflow request.",
                    },
                  },
                },
              },
              description = "A list of mappings defining how to extract values from the Dialogflow request and store them in `kong.ctx.shared`.",
            },
          },
          {
            output_key_prefix = {
              type = "string",
              default = "",
              description = "Optional: A prefix to prepend to all `output_key`s before storing them in `kong.ctx.shared`.",
            },
          },
          {
            on_parse_error_status = {
              type = "number",
              default = 400,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if the Dialogflow request body is not valid JSON or cannot be processed, and `on_parse_error_continue` is `false`.",
            },
          },
          {
            on_parse_error_body = {
              type = "string",
              default = "Invalid Dialogflow request format.",
              description = "The response body to return to the client if parsing fails and `on_parse_error_continue` is `false`.",
            },
          },
          {
            on_parse_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request processing will continue even if parsing the Dialogflow request fails. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
