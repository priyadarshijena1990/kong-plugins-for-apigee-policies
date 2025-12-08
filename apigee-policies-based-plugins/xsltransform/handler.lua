local saxon = require "saxon"
local kong_meta = require "kong.meta"

local XslTransformHandler = {}

XslTransformHandler.PRIORITY = 1000
XslTransformHandler.VERSION = kong_meta.version

function XslTransformHandler:new()
  return {
    -- Standard constructor
  }
end

local function get_source_value(source_type, source_name)
  if source_type == "shared_context" then
    return kong.ctx.shared[source_name]
  end
  -- This function is only for shared_context, other sources are handled directly.
  return nil
end

local function handle_error(conf, message)
  kong.log.err(message)
  if not conf.on_error_continue then
    return kong.response.exit(conf.on_error_status, conf.on_error_body)
  end
end

function XslTransformHandler:access(conf)
  -- This phase handles transformations on the request body.
  if conf.xml_source ~= "request_body" and (conf.xml_source == "shared_context" and conf.output_destination ~= "replace_request_body") then
    return -- Not a request transformation, so we'll run in the response phase or just manipulate shared context.
  end

  -- Prepare parameters for the stylesheet
  local params = {}
  if conf.parameters then
    for _, p in ipairs(conf.parameters) do
      if p.value_from == "literal" then
        params[p.name] = p.value
      elseif p.value_from == "shared_context" then
        params[p.name] = get_source_value("shared_context", p.value) or ""
      end
    end
  end

  -- Locate the XSL file
  local xsl_path = kong.plugins.find_file("xsltransform", "xsl/" .. conf.xsl_file)
  if not xsl_path then
    return handle_error(conf, "XSL file not found: " .. conf.xsl_file)
  end

  -- Perform the transformation
  local transformed_xml, err = saxon.transform(xsl_path, xml_string, params)
  if err then
    return handle_error(conf, "XSL transformation failed: " .. err)
  end

  -- Handle the output
  if conf.output_destination == "replace_request_body" then
    kong.service.request.set_raw_body(transformed_xml)
    kong.service.request.set_header("Content-Length", #transformed_xml)
    kong.service.request.set_header("Content-Type", conf.content_type)
  elseif conf.output_destination == "shared_context" then
    kong.ctx.shared[conf.output_destination_name] = transformed_xml
  end
end

function XslTransformHandler:body_filter(conf)
  -- This phase handles transformations on the response body.
  if conf.xml_source ~= "response_body" then
    return -- Not a response body transformation.
  end

  -- Check if we are processing the last chunk of the response body
  local chunk, eof = kong.response.get_raw_body_chunk()
  if not eof then
    return -- Wait for the full body
  end

  local xml_string, err = kong.response.get_raw_body()
  if err then
    return handle_error(conf, "Failed to get response body: " .. err)
  end

  if not xml_string or xml_string == "" then
    return handle_error(conf, "XML source (response body) is empty.")
  end

  -- Prepare parameters
  local params = {}
  if conf.parameters then
    for _, p in ipairs(conf.parameters) do
      if p.value_from == "literal" then
        params[p.name] = p.value
      elseif p.value_from == "shared_context" then
        params[p.name] = get_source_value("shared_context", p.value) or ""
      end
    end
  end

  local xml_string
  if conf.xml_source == "request_body" then
    local raw_body, err = kong.request.get_raw_body()
    if err then
      return handle_error(conf, "Failed to get request body: " .. tostring(err))
    end
    xml_string = raw_body
  else -- 'shared_context'
    xml_string = get_source_value("shared_context", conf.xml_source_name)
  end

  if not xml_string or xml_string == "" then
    return handle_error(conf, "XML source is empty or not found.")
  end

  -- Locate the XSL file
  local xsl_path = kong.plugins.find_file("xsltransform", "xsl/" .. conf.xsl_file)
  if not xsl_path then
    return handle_error(conf, "XSL file not found: " .. conf.xsl_file)
  end

  -- Perform the transformation
  local transformed_xml, err = saxon.transform(xsl_path, xml_string, params)
  if err then
    return handle_error(conf, "XSL transformation failed: " .. tostring(err))
  end

  -- Handle the output
  if conf.output_destination == "replace_response_body" then
    kong.response.set_raw_body(transformed_xml)
    kong.response.set_header("Content-Length", #transformed_xml)
    kong.response.set_header("Content-Type", conf.content_type)
  elseif conf.output_destination == "shared_context" then
    -- This might be less common in body_filter but supported for completeness
    kong.ctx.shared[conf.output_destination_name] = transformed_xml
  end
end

-- To support custom ordering if needed
function XslTransformHandler:get_plugin_order()
  return {
    -- Example: ensure it runs after another plugin
    -- ["another-plugin"] = { after = true }
  }
end

return XslTransformHandler