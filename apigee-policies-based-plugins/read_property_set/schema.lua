local typedefs = require "kong.db.schema.typedefs"

return {
  name = "read-property-set",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            property_set_name = {
              type = "string",
              required = true,
              description = "A logical name for this set of properties, similar to Apigee's PropertySetName.",
            },
          },
          {
            properties = {
              type = "map",
              required = true,
              description = "A map of key-value pairs representing the PropertySet.",
            },
          },
          {
            assign_to_shared_context_key = {
              type = "string",
              description = "Optional: If set, the entire map of properties will be assigned to this key in kong.ctx.shared. If omitted, individual properties are assigned using the pattern `property_set_name.propertyName`.",
            },
          },
        },
      },
    },
  },
}
