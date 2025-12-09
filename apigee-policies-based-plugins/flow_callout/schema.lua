local typedefs = require "kong.db.schema.typedefs"

return {
  name = "flow-callout",
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
            shared_flow_service_name = {
              type = "string",
              required = true,
              description = "The name of the Kong Service that represents the 'shared flow' to be executed internally. This Service should be configured with the necessary plugins and upstream for your shared logic.",
            },
          },
          {
            preserve_original_request_body = {
              type = "boolean",
              default = true,
              description = "If `true`, the plugin will attempt to re-read the original client request body after the internal sub-request, making it available for the original upstream.",
            },
          },
          {
            on_flow_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if the internal shared flow call fails and `on_flow_error_continue` is `false`.",
            },
          },
          {
            on_flow_error_body = {
              type = "string",
              default = "Shared Flow execution failed.",
              description = "The response body to return to the client if the internal shared flow call fails and `on_flow_error_continue` is `false`.",
            },
          },
          {
            on_flow_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, the main request processing will continue even if the internal shared flow call fails. If `false`, the request will be terminated.",
            },
          },
          {
            store_flow_response_in_shared_context_key = {
              type = "string",
              description = "Optional: If set, the internal shared flow's full response (status, headers, body) will be stored in `kong.ctx.shared` under this key, as a Lua table.",
            },
          },
        },
      },
    },
  },
}
