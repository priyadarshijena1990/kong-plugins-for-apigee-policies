local typedefs = require "kong.db.schema.typedefs"

return {
  name = "service-callout",
  priority = 1000, -- Adding priority for custom ordering
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            callout_url = {
              type = "string",
              required = true,
              description = "The URL of the external service endpoint to call.",
            },
          },
          {
            method = {
              type = "string",
              default = "POST",
              enum = { "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS" },
              description = "The HTTP method for the callout request.",
            },
          },
          {
            headers = {
              type = "map",
              default = {},
              description = "Optional: Headers to send with the callout request.",
            },
          },
          {
            request_body_source_type = {
              type = "string",
              default = "request_body",
              enum = { "request_body", "shared_context", "none" },
              description = "Specifies where to get the request body to send to the external service.",
            },
          },
          {
            request_body_source_name = {
              type = "string",
              description = "Required if `request_body_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the content to send as the body.",
            },
          },
          {
            wait_for_response = {
              type = "boolean",
              default = true,
              description = "If `false`, the plugin will make the callout but will not wait for the external service's response. This effectively makes it a 'fire and forget' operation, and response handling/error handling will be skipped for the main flow.",
            },
          },
          {
            response_to_shared_context_key = {
              type = "string",
              description = "Optional: If set and `wait_for_response` is `true`, the external service's full response (status, headers, body) will be stored in `kong.ctx.shared` under this key, as a Lua table.",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if the external callout fails, `wait_for_response` is `true`, and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "External Callout failed.",
              description = "The response body to return to the client if the external callout fails, `wait_for_response` is `true`, and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, the main request processing will continue even if the external callout fails (only applicable if `wait_for_response` is `true`). If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}