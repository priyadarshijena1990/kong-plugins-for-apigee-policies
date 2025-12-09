local typedefs = require "kong.db.schema.typedefs"

return {
  name = "get-oauth-v2-info",
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
            extract_client_id_to_shared_context_key = {
              type = "string",
              description = "Optional: Key in `kong.ctx.shared` to store the authenticated client ID.",
            },
          },
          {
            extract_app_name_to_shared_context_key = {
              type = "string",
              description = "Optional: Key in `kong.ctx.shared` to store the authenticated application name (from credential.name).",
            },
          },
          {
            extract_end_user_to_shared_context_key = {
              type = "string",
              description = "Optional: Key in `kong.ctx.shared` to store the authenticated end-user identifier (from consumer.username or consumer.custom_id).",
            },
          },
          {
            extract_scopes_to_shared_context_key = {
              type = "string",
              description = "Optional: Key in `kong.ctx.shared` to store the OAuth scopes associated with the token.",
            },
          },
          {
            extract_custom_attributes = {
              type = "array",
              default = {},
              elements = {
                type = "record",
                fields = {
                  {
                    source_field = {
                      type = "string",
                      required = true,
                      description = "The field name (e.g., 'custom_attribute_1') to extract from the authenticated consumer or credential object.",
                    },
                  },
                  {
                    output_key = {
                      type = "string",
                      required = true,
                      description = "The key in `kong.ctx.shared` where the extracted custom attribute will be stored.",
                    },
                  },
                },
              },
              description = "Optional: Define custom attributes to extract from the authenticated consumer or credential objects and store in `kong.ctx.shared`.",
            },
          },
        },
      },
    },
  },
}
