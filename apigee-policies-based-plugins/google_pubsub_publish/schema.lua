local typedefs = require "kong.db.schema.typedefs"

return {
  name = "google-pubsub-publish",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            phase = {
              type = "string",
              required = true,
              enum = { "access", "log" },
              default = "log",
              description = "The Kong phase in which to execute the Pub/Sub publish operation. 'access' allows blocking on failure, 'log' makes it asynchronous (fire-and-forget).",
            },
          },
          {
            gcp_project_id = {
              type = "string",
              required = true,
              description = "The Google Cloud Project ID where the Pub/Sub topic resides.",
            },
          },
          {
            pubsub_topic_name = {
              type = "string",
              required = true,
              description = "The name of the Google Cloud Pub/Sub topic to publish the message to.",
            },
          },
          {
            gcp_access_token_source_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "body", "shared_context", "literal" },
              description = "Specifies where to get the Google Cloud access token for authenticating the Pub/Sub API call.",
            },
          },
          {
            gcp_access_token_source_name = {
              type = "string",
              description = "The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `gcp_access_token_source_type` is 'literal'.",
            },
          },
          {
            message_payload_source_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "body", "shared_context", "literal" },
              description = "Specifies where to get the message content (payload) that will be published to Pub/Sub.",
            },
          },
          {
            message_payload_source_name = {
              type = "string",
              description = "The name of the header/query parameter, the JSON path for a 'body' source, the key in `kong.ctx.shared`, or the literal value itself if `message_payload_source_type` is 'literal'.",
            },
          },
          {
            message_attributes = {
              type = "map",
              default = {},
              description = "Optional: A map of key-value pairs to attach as attributes to the Pub/Sub message. Values can reference flow variables (e.g., `{request.headers.X-Transaction-ID}`).",
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
              description = "Applicable in 'access' phase: The HTTP status code to return to the client if message publishing fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "Message publishing failed.",
              description = "Applicable in 'access' phase: The response body to return to the client if message publishing fails and `on_error_continue` is `false`.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "Applicable in 'access' phase: If `true`, request processing will continue even if message publishing fails. If `false`, the request will be terminated.",
            },
          },
        },
      },
    },
  },
}
