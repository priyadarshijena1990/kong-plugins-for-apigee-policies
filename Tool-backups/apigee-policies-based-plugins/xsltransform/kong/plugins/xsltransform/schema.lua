-- schema.lua for xsltransform plugin
-- Updated to include custom validation for parameters
local typedefs = require "kong.db.schema.typedefs"

return {
  name = "xsltransform",
  fields = {
    { consumer = typedefs.foreign_relation, },
    { protocols = typedefs.protocols, },
    { config = {
        type = "record",
        fields = {
          { stylesheet_resource = { type = "string", required = true,
                                    -- Example: "xsl/My-Transformation.xsl"
                                    -- Path relative to the plugin's root, i.e., plugins/xsltransform/xsl/My-Transformation.xsl
                                    }, },
          { source_variable = { type = "string", default = "request", enum = { "request", "response" }, }, },
          { output_variable = { type = "string", default = "transformed_message", }, },
          { parameters = {
              type = "array",
              schema = {
                type = "record",
                fields = {
                  { name = { type = "string", required = true }, },
                  { value = { type = "string" }, },   -- Static value
                  { ref = { type = "string" }, },     -- Reference to Kong variable
                },
                custom_validator = function(value)
                  if (value.value and value.ref) or (not value.value and not value.ref) then
                    return nil, "either 'value' or 'ref' must be provided, but not both"
                  end
                end
              },
            }, }, },
        },
      }, },
  },
}