local dkjson = require "dkjson"
local xml = require "xml"
local kong_meta = require "kong.meta"

local JsonToXmlHandler = {}

JsonToXmlHandler.PRIORITY = 990
JsonToXmlHandler.VERSION = kong_meta.version

local function handle_error(conf, message)
  kong.log.err(message)
  if not conf.on_error_continue then
    return kong.response.exit(conf.on_error_status, { message = message })
  end
end

local function get_json_source(source_type, source_name)
  if source_type == "request_body" then
    return kong.request.get_raw_body()
  elseif source_type == "response_body" then
    return kong.response.get_raw_body()
  elseif source_type == "shared_context" then
    local data = kong.ctx.shared[source_name]
    if type(data) == "table" then
      return dkjson.encode(data)
    end
    return data -- Assume it's already a JSON string
  end
  return nil, "Invalid source_type"
end

local function perform_conversion(conf, json_string)
  if not json_string or json_string == "" then
    return nil, "JSON source is empty or not found."
  end

  local ok, json_table = pcall(dkjson.decode, json_string)
  if not ok then
    return nil, "Failed to decode JSON: " .. (json_table or "unknown error")
  end

  -- The xml library expects a single root table
  local root_name = conf.root_element_name or "root"
  local xml_table = { [root_name] = json_table }

  local ok, xml_string = pcall(xml.encode, xml_table)
  if not ok then
    return nil, "Failed to encode XML: " .. (xml_string or "unknown error")
  end

  return xml_string
end

function JsonToXmlHandler:access(conf)
  -- This phase handles transformations on the request
  if conf.json_source ~= "request_body" and conf.json_source ~= "shared_context" then
    return -- Not a request-side transformation
  end

  local json_string, err = get_json_source(conf.json_source, conf.json_source_name)
  if err then
    return handle_error(conf, err)
  end

  local xml_string, err = perform_conversion(conf, json_string)
  if err then
    return handle_error(conf, err)
  end

  -- Handle the output
  if conf.output_destination == "replace_request_body" then
    kong.service.request.set_raw_body(xml_string)
    kong.service.request.set_header("Content-Length", #xml_string)
    kong.service.request.set_header("Content-Type", conf.content_type)
  elseif conf.output_destination == "shared_context" then
    kong.ctx.shared[conf.output_destination_name] = xml_string
  end
end

function JsonToXmlHandler:body_filter(conf)
  -- This phase handles transformations on the response body
  if conf.json_source ~= "response_body" then
    return
  end

  local json_string, err = get_json_source(conf.json_source)
  if err then
    return handle_error(conf, "Failed to get response body: " .. err)
  end

  local xml_string, err = perform_conversion(conf, json_string)
  if err then
    -- In body_filter, we can't easily exit. We log the error and, if not continuing,
    -- replace the body with an error message.
    kong.log.err("JSON to XML transformation failed: ", err)
    if not conf.on_error_continue then
      kong.response.set_status(conf.on_error_status)
      kong.response.set_body({ message = conf.on_error_body })
    end
    return
  end

  -- Handle the output
  kong.response.set_raw_body(xml_string)
  kong.response.set_header("Content-Length", #xml_string)
  kong.response.set_header("Content-Type", conf.content_type)
end

return JsonToXmlHandler