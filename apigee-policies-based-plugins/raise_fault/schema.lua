local typedefs = require "kong.db.schema.typedefs"

return {
  name = "raise-fault",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            status_code = {
              type = "number",
              required = true,
              between = { 400, 599 },
              description = "The HTTP status code to return.",
            },
          },
          {
            fault_body = {
              type = "string",
              description = "The raw string to be used as the response body. Can be JSON, XML, or plain text.",
            },
          },
          {
            headers = {
              type = "map",
              keys = { type = "string" },
              values = { type = "string" },
              description = "A map of headers to add to the fault response.",
            },
          },
          {
            content_type = {
              type = "string",
              default = "application/json",
              description = "The 'Content-Type' header of the fault response. This is a convenience and will be overridden by a 'Content-Type' header in the 'headers' map.",
            },
          },
        },
      },
    },
  },
}