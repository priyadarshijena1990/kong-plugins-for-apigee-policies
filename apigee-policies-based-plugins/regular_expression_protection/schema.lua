local typedefs = require "kong.db.schema.typedefs"

return {
  name = "regular-expression-protection",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            sources = {
              type = "array",
              required = true,
              elements = {
                type = "record",
                fields = {
                  {
                    source_type = {
                      type = "string",
                      required = true,
                      enum = { "header", "query", "path", "body" },
                      description = "The type of request component to check (header, query, path, or body).",
                    },
                  },
                  {
                    source_name = {
                      type = "string",
                      description = "Required for 'header', 'query', 'body' types. Header name, query parameter name, or JSON path for 'body' (e.g., 'user.data'). For 'path', the full URI is checked.",
                    },
                  },
                  {
                    patterns = {
                      type = "array",
                      required = true,
                      elements = {
                        type = "string",
                        description = "A list of regular expression patterns to match against the content of this source.",
                      },
                      description = "The regular expression patterns to apply to the content of this source.",
                    },
                  },
                },
              },
              description = "A list of sources (headers, query params, path, body) to apply regular expression protection to.",
            },
          },
          {
            match_action = {
              type = "string",
              default = "abort",
              enum = { "abort", "continue" },
              description = "The action to take if any pattern matches. 'abort' terminates the request, 'continue' logs the violation but allows the request to proceed.",
            },
          },
          {
            violation_status = {
              type = "number",
              default = 403,
              between = { 400, 599 },
              description = "The HTTP status code to return when a violation is detected and `match_action` is 'abort'.",
            },
          },
          {
            violation_body = {
              type = "string",
              default = "Malicious input detected. Request blocked.",
              description = "The response body to return when a violation is detected and `match_action` is 'abort'.",
            },
          },
        },
      },
    },
  },
}
