local cjson = require "cjson"
local xml2lua = require "xml2lua"
local kong_meta = require "kong.meta"

local XmlToJsonHandler = {}

XmlToJsonHandler.PRIORITY = 980
XmlToJsonHandler.VERSION = kong_meta.version

local function handle_error(conf, message)
  kong.log.err(message)
  if not conf.on_error_continue then
    return kong.response.exit(conf.on_error_status, { message = message })
  end
end

local function get_xml_source(source_type, source_name)
  if source_type == "request_body" then
    return kong.request.get_raw_body()
  elseif source_type == "response_body" then
    return kong.response.get_raw_body()
  elseif source_type == "shared_context" then
    return kong.ctx.shared[source_name]
  end
  return nil, "Invalid source_type"
end

local function perform_conversion(conf, xml_string)
  if not xml_string or xml_string == "" then
    return nil, "XML source is empty or not found."
  end

  local parser = xml2lua.parser()
  local ok, xml_table = pcall(parser.parse, parser, xml_string)

  if not ok then
    return nil, "Failed to parse XML: " .. (xml_table or "unknown error")
  end

  local ok, json_string = pcall(cjson.encode, xml_table)
  if not ok then
    return nil, "Failed to encode JSON: " .. (json_string or "unknown error")
  end

  return json_string
end

function XmlToJsonHandler:access(conf)
  -- This phase handles transformations on the request
  if conf.xml_source ~= "request_body" and conf.xml_source ~= "shared_context" then
    return -- Not a request-side transformation
  end

  local xml_string, err = get_xml_source(conf.xml_source, conf.xml_source_name)
  if err then
    return handle_error(conf, err)
  end

  local json_string, err = perform_conversion(conf, xml_string)
  if err then
    return handle_error(conf, err)
  end

  -- Handle the output
  if conf.output_destination == "replace_request_body" then
    kong.service.request.set_raw_body(json_string)
    kong.service.request.set_header("Content-Length", #json_string)
    kong.service.request.set_header("Content-Type", conf.content_type)
  elseif conf.output_destination == "shared_context" then
    kong.ctx.shared[conf.output_destination_name] = json_string
  end
end

function XmlToJsonHandler:body_filter(conf)
  -- This phase handles transformations on the response body
  if conf.xml_source ~= "response_body" then
    return
  end

  local xml_string, err = get_xml_source(conf.xml_source)
  if err then
    return handle_error(conf, "Failed to get response body: " .. err)
  end

  local json_string, err = perform_conversion(conf, xml_string)
  if err then
    kong.log.err("XML to JSON transformation failed: ", err)
    if not conf.on_error_continue then
      -- In body_filter, we cannot exit. We replace the body with an error.
      kong.response.set_status(conf.on_error_status)
      kong.response.set_body({ message = conf.on_error_body })
    end
    return
  end

  -- Handle the output
  kong.response.set_raw_body(json_string)
  kong.response.set_header("Content-Length", #json_string)
  kong.response.set_header("Content-Type", conf.content_type)
end

return XmlToJsonHandler