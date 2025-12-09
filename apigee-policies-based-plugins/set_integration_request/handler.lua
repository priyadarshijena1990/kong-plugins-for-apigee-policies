local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson" -- Kong usually has cjson available
local fun = require "kong.tools.functional"

local SetIntegrationRequestHandler = BasePlugin:extend("set-integration-request")

function SetIntegrationRequestHandler:new()
  return SetIntegrationRequestHandler.super.new(self, "set-integration-request")
end

function SetIntegrationRequestHandler:rewrite(conf)
  SetIntegrationRequestHandler.super.rewrite(self)

  local integration_request_info = {
    integration_name = conf.integration_name,
    trigger_name = conf.trigger_name,
    parameters = {}
  }

  local request_body = nil
  local parsed_body = nil

  for _, param_conf in ipairs(conf.parameters) do
    local param_name = param_conf.name
    local param_type = param_conf.type
    local param_source = param_conf.source
    local param_source_name = param_conf.source_name
    local param_value = nil

    if param_source == "literal" then
      param_value = param_conf.value
    elseif param_source == "header" then
      param_value = kong.request.get_header(param_source_name)
    elseif param_source == "query" then
      param_value = kong.request.get_query_arg(param_source_name)
    elseif param_source == "body" then
      if not request_body then
        request_body = kong.request.get_raw_body()
        if request_body and request_body ~= "" then
          local ok, decoded = pcall(cjson.decode, request_body)
          if ok then
            parsed_body = decoded
          else
            kong.log.warn("SetIntegrationRequest plugin: Failed to decode request body as JSON for parameter '", param_name, "'. Error: ", decoded)
          end
        end
      end

      if parsed_body then
        if not param_source_name or param_source_name == "" or param_source_name == "." then
          -- If source_name is empty or ".", use the whole parsed body
          param_value = parsed_body
        else
          -- Assume top-level key for simplicity
          param_value = parsed_body[param_source_name]
        end
      end
    end

    -- Type conversion
    if param_value ~= nil then
      if param_type == "INT" then
        param_value = tonumber(param_value)
        if not param_value then
          kong.log.warn("SetIntegrationRequest plugin: Parameter '", param_name, "' value '", tostring(param_value), "' could not be converted to INT.")
        end
      elseif param_type == "BOOLEAN" then
        if type(param_value) == "string" then
          local lower_val = param_value:lower()
          if lower_val == "true" then
            param_value = true
          elseif lower_val == "false" then
            param_value = false
          else
            param_value = nil -- or raise error, or keep original string
            kong.log.warn("SetIntegrationRequest plugin: Parameter '", param_name, "' value '", param_value, "' could not be converted to BOOLEAN. Expected 'true' or 'false'.")
          end
        elseif type(param_value) == "boolean" then
          -- Already a boolean
        else
          param_value = nil -- Not a string or boolean, cannot convert
          kong.log.warn("SetIntegrationRequest plugin: Parameter '", param_name, "' value '", type(param_value), "' type could not be converted to BOOLEAN. Expected string or boolean.")
        end
      elseif param_type == "JSON" then
        if type(param_value) == "string" then
          local ok, decoded = pcall(cjson.decode, param_value)
          if ok then
            param_value = decoded
          else
            kong.log.warn("SetIntegrationRequest plugin: Parameter '", param_name, "' value '", param_value, "' could not be converted to JSON string. Keeping as string.")
          end
        end
        -- If already a table (from body extraction), keep as is
      end
    end

    integration_request_info.parameters[param_name] = param_value
  end

  kong.ctx.shared.integration_request = integration_request_info
  kong.log.debug("SetIntegrationRequest plugin: Extracted Integration Request info: ", fun.json_encode(integration_request_info))
end

return SetIntegrationRequestHandler
