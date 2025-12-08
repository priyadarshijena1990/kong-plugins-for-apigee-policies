local typedefs = require "kong.db.schema.typedefs"

return {
  name = "key-value-map-operations",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            policy = {
              type = "string",
              required = true,
              enum = { "local", "cluster" },
              default = "local",
              description = "The policy to use for storing KVM data. 'local' uses a shared memory dictionary on each node. 'cluster' uses the Kong database to share data across all nodes.",
            },
          },
          {
            kvm_name = {
              type = "string",
              required = true,
              description = "The name of the KVM. For 'local' policy, this is the name of the shared dictionary. For 'cluster' policy, this is a namespace within the shared KVM table.",
            },
          },
          {
            operation_type = {
              type = "string",
              required = true,
              enum = { "get", "put", "delete" },
              description = "The Key-Value Map operation to perform.",
            },
          },
          {
            key_source_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "body", "shared_context", "literal" },
              description = "Specifies where to get the key for the KVM operation.",
            },
          },
          {
            key_source_name = {
              type = "string",
              description = "The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `key_source_type` is 'literal'.",
            },
          },
          {
            value_source_type = {
              type = "string",
              enum = { "header", "query", "body", "shared_context", "literal" },
              description = "Required for 'put' operation: Specifies where to get the value to put into the KVM.",
            },
          },
          {
            value_source_name = {
              type = "string",
              description = "Required for 'put' operation: The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `value_source_type` is 'literal'.",
            },
          },
          {
            output_destination_type = {
              type = "string",
              enum = { "header", "query", "body", "shared_context" },
              description = "Required for 'get' operation: Specifies where to place the retrieved value.",
            },
          },
          {
            output_destination_name = {
              type = "string",
              description = "Required for 'get' operation: The name of the header/query parameter, the JSON path for a 'body' destination, or the key in `kong.ctx.shared` where the retrieved value will be stored.",
            },
          },
          {
            ttl = {
              type = "number",
              between = { 0, 31536000 }, -- 0 for no expiry, up to 1 year
              description = "Optional, for 'put' operation: Time-to-live for the entry in seconds. If 0, the entry does not expire. Defaults to no expiry if not set.",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
              description = "The HTTP status code to return to the client if the KVM operation fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "Key-Value Map operation failed.",
              description = "The response body to return to the client if the KVM operation fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If `true`, request processing will continue even if the KVM operation fails. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
