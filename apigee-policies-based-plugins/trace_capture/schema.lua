local typedefs = require "kong.db.schema.typedefs"

return {
  name = "trace-capture",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            trace_points = {
              type = "array",
              required = true,
              elements = {
                type = "record",
                fields = {
                  {
                    name = {
                      type = "string",
                      required = true,
                      description = "A unique name for this captured data point (e.g., 'user_id', 'request_payload_size').",
                    },
                  },
                  {
                    source_type = {
                      type = "string",
                      required = true,
                      enum = { "header", "query", "path", "body", "shared_context", "literal", "response_header", "response_body", "status", "latency" },
                      description = "Specifies where to get the value for this trace point from.",
                    },
                  },
                  {
                    source_name = {
                      type = "string",
                      description = "Required for 'header', 'query', 'body', 'response_header', 'response_body', 'shared_context' types. Header name, query parameter name, JSON path for body/response_body, shared context key, or the literal value itself if `source_type` is 'literal'. Not used for 'path', 'status', 'latency'.",
                    },
                  },
                },
              },
              description = "A list defining the data points to capture during the API flow.",
            },
          },
          {
            store_in_shared_context_prefix = {
              type = "string",
              description = "Optional: If set, all captured data points will be stored in `kong.ctx.shared` with this prefix (e.g., 'trace_data.user_id'). If empty, items will be stored directly by their `name`.",
            },
          },
          {
            external_logger_url = {
              type = "string",
              description = "Optional: The URL of an external service to send the captured trace data to. This call happens in the 'log' phase.",
            },
          },
          {
            method = {
              type = "string",
              default = "POST",
              enum = { "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS" },
              description = "The HTTP method for the call to the external logger, if `external_logger_url` is configured.",
            },
          },
          {
            headers = {
              type = "map",
              default = {},
              description = "Optional: Headers to send with the request to the external logger.",
            },
          },
          {
            timeout = {
              type = "number",
              default = 5000,
              between = { 100, 60000 },
              description = "The timeout in milliseconds for the HTTP call to the external logger.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = true,
              description = "If `true`, request processing (and external logging in 'log' phase) will continue even if an error occurs during data retrieval or external call. If `false`, it might terminate the request (in 'access' phase) or just log an error (in 'log' phase).",
            },
          },
        },
      },
    },
  },
}
