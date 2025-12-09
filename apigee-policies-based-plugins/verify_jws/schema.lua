local typedefs = require "kong.db.schema.typedefs"

return {
  name = "service-callout",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            url = {
              type = "string",
              required = true,
              description = "The full URL of the external service to call.",
            },
          },
          {
            method = {
              type = "string",
              default = "GET",
              enum = { "GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD" },
              description = "The HTTP method for the callout.",
            },
          },
          {
            headers = {
              type = "map",
              keys = { type = "string" },
              values = { type = "string" },
              description = "A map of headers to send with the callout request.",
            },
          },
          {
            query_params = {
              type = "map",
              keys = { type = "string" },
              values = { type = "string" },
              description = "A map of query parameters to append to the URL.",
            },
          },
          {
            body = {
              type = "string",
              description = "The request body to send for POST, PUT, or PATCH requests.",
            },
          },
          {
            timeout = {
              type = "number",
              default = 10000, -- 10 seconds
              description = "Timeout in milliseconds for waiting for the callout response.",
            },
          },
          {
            ssl_verify = {
              type = "boolean",
              default = false,
              description = "If true, verifies the SSL certificate of the external service.",
            },
          },
          {
            fire_and_forget = {
              type = "boolean",
              default = false,
              description = "If true, the plugin will not wait for the callout to complete (non-blocking).",
            },
          },
          {
            output_variable_name = {
              type = "string",
              description = "If provided, the response (status, headers, body) from the callout will be stored in `kong.ctx.shared` under this key.",
            },
          },
          {
            on_error_continue = { type = "boolean", default = false },
          },
        },
      },
    },
  },
}