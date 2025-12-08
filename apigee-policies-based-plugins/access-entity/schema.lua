local typedefs = require "kong.db.schema.typedefs"

return {
  name = "access-entity",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            context_variable_name = {
              type = "string",
              default = "consumer_entity",
              description = "The name of the variable in `kong.ctx.shared` where the consumer entity details will be stored.",
            },
          },
        },
      },
    },
  },
}