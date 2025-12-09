local typedefs = require "kong.db.schema.typedefs"

return {
  name = "assert-condition",
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    {
      config = {
        type = "record",
        fields = {
          {
            condition = {
              type = "string",
              required = true,
              description = "A Lua expression string that evaluates to true or false. Kong variables (e.g., `kong.request.get_header('X-My-Header')`) and shared context (`kong.ctx.shared.my_var`) can be used.",
            },
          },
          {
            on_false_action = {
              type = "string",
              required = true,
              enum = { "abort", "continue" },
              description = "The action to take if the 'condition' evaluates to false. 'abort' terminates the request, 'continue' allows it to proceed.",
            },
          },
          {
            abort_status = {
              type = "number",
              default = 400,
              between = { 400, 599 },
              description = "The HTTP status code to return if 'on_false_action' is 'abort' and the condition is false.",
            },
          },
          {
            abort_message = {
              type = "string",
              default = "Condition not met.",
              description = "The response body message to return if 'on_false_action' is 'abort' and the condition is false.",
            },
          },
          {
            on_error_continue = {
              type = "boolean",
              default = false,
              description = "If true, continues processing even if there's an error evaluating the 'condition' expression. If false, terminates the request with a 500 error.",
            },
          },
        },
      },
    },
  },
}