local typedefs = require "kong.db.schema.typedefs"

return {
  name = "statistics-collector",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            collection_service_url = {
              type = "string",
              required = true,
              description = "The URL of the external service endpoint to send collected statistics to.",
            },
          },
          {
            method = {
              type = "string",
              default = "POST",
              enum = { "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS" },
              description = "The HTTP method for the call to the statistics collection service.",
            },
          },
          {
            headers = {
              type = "map",
              default = {},
              description = "Optional: Headers to send with the request to the statistics collection service.",
            },
          },
          {
            statistics_to_collect = {
              type = "array",
              required = true,
              elements = {
                type = "record",
                fields = {
                  {
                    name = {
                      type = "string",
                      required = true,
                      description = "The name of the statistic or metric to collect (e.g., 'transaction_amount', 'developer_email').",
                    },
                  },
                  {
                    source_type = {
                      type = "string",
                      required = true,
                      enum = { "header", "query", "path", "body", "shared_context", "literal" },
                      description = "Specifies where to get the value for this statistic from.",
                    },
                  },
                  {
                    source_name = {
                      type = "string",
                      description = "The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `source_type` is 'literal'.",
                    },
                  },
                  {
                    value_type = {
                      type = "string",
                      enum = { "string", "number", "boolean" },
                      description = "Optional: A type hint for the external collection service. Kong will attempt to convert the value to this type if possible.",
                    },
                  },
                },
              },
              description = "A list of data points (statistics) to extract and send to the external collection service.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = true, -- Default to true as statistics collection is often non-critical
              description = "If `true`, request processing will continue even if sending statistics fails. If `false`, the request will be terminated.",
            },
          },
          {
            timeout = {
              type = "number",
              default = 5000,
              between = { 100, 60000 },
              description = "The timeout in milliseconds for the HTTP call to the statistics collection service.",
            },
          },
        },
      },
    },
  },
}
