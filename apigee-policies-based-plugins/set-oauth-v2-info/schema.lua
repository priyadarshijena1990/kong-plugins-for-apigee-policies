local typedefs = require "kong.db.schema.typedefs"

return {
  name = "set-oauth-v2-info",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            custom_attributes = {
              type = "array",
              default = {},
              elements = {
                type = "string",
                -- The 'custom_attributes' field will be an array of strings,
                -- where each string is the name of a custom attribute to extract.
              },
            },
          },
        },
      },
    },
  },
}