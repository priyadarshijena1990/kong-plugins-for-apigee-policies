local typedefs = require "kong.db.schema.typedefs"

return {
  name = "reset-quota",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            admin_api_url = {
              type = "string",
              required = true,
              description = "The base URL of Kong's Admin API (e.g., 'http://kong-admin:8001').",
            },
          },
          {
            admin_api_key = {
              type = "string",
              description = "Optional: An API key to authenticate with Kong's Admin API, if secured.",
            },
          },
          {
            rate_limiting_plugin_id = {
              type = "string",
              required = true,
              description = "The ID of the specific 'rate-limiting' plugin instance whose quota is to be reset. This ID can be found in Kong's Admin API configuration for the plugin.",
            },
          },
          {
            scope_type = {
              type = "string",
              enum = { "consumer", "service", "route" },
              description = "Optional: The type of entity the quota is scoped by (e.g., 'consumer', 'service', 'route'). If omitted, a global counter for the plugin will be reset.",
            },
          },
          {
            scope_id_source_type = {
              type = "string",
              description = "Required if `scope_type` is set: Specifies where to get the ID of the scoped entity.",
            },
          },
          {
            scope_id_source_name = {
              type = "string",
              description = "Required if `scope_type` is set: The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal ID value itself if `scope_id_source_type` is 'literal'.",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if the quota reset operation fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "Quota reset failed.",
              description = "The response body to return to the client if the quota reset operation fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request processing will continue even if the quota reset operation fails. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
