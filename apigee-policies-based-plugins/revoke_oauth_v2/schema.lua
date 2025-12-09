local typedefs = require "kong.db.schema.typedefs"

return {
  name = "revoke-oauth-v2",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            revocation_endpoint = {
              type = "string",
              required = true,
            },
          },
          {
            client_id = {
              type = "string",
              required = true,
            },
          },
          {
            client_secret = {
              type = "string",
              -- Optional, depending on OAuth provider's requirements
            },
          },
          {
            token_source_type = {
              type = "string",
              required = true,
              enum = { "header", "query", "body", "shared_context" },
            },
          },
          {
            token_source_name = {
              type = "string",
              required = true,
              -- The name of the header/query param/JSON path for body/shared context key
            },
          },
          {
            token_type_hint = {
              type = "string",
              enum = { "access_token", "refresh_token" },
              -- Optional hint to the revocation endpoint
            },
          },
          {
            on_error_status = {
              type = "number",
              default = 500,
              between = { 400, 599 },
            },
          },
          {
            on_error_body = {
              type = "string",
              default = "Token revocation failed.",
            },
          },
          {
            on_success_status = {
              type = "number",
              default = 200,
              between = { 200, 299 },
            },
          },
          {
            on_success_body = {
              type = "string",
              default = "Token revoked successfully.",
            },
          },
        },
      },
    },
  },
}
