local BasePlugin = require "kong.plugins.base_plugin"
local fun = require "kong.tools.functional"

local ReadPropertySetHandler = BasePlugin:extend("read-property-set")

function ReadPropertySetHandler:new()
  return ReadPropertySetHandler.super.new(self, "read-property-set")
end

function ReadPropertySetHandler:access(conf)
  ReadPropertySetHandler.super.access(self)

  if not conf.properties then
    kong.log.err("ReadPropertySet: No properties configured.")
    return
  end

  if conf.assign_to_shared_context_key then
    kong.ctx.shared[conf.assign_to_shared_context_key] = conf.properties
    kong.log.debug("ReadPropertySet: Assigned entire PropertySet '", conf.property_set_name, "' to shared context key '", conf.assign_to_shared_context_key, "'")
  else
    for key, value in pairs(conf.properties) do
      local shared_key = conf.property_set_name .. "." .. key
      kong.ctx.shared[shared_key] = value
      kong.log.debug("ReadPropertySet: Assigned property '", key, "' to shared context key '", shared_key, "'")
    end
    kong.log.debug("ReadPropertySet: Assigned individual properties from PropertySet '", conf.property_set_name, "' to shared context.")
  end
end

return ReadPropertySetHandler
