local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local xml = require "lua-xml" -- Kong typically includes lua-xml or similar

local XMLToJSONHandler = BasePlugin:extend("xml-to-json")

-- Helper function to recursively convert XML table to JSON table
local function xml_to_json_table(xml_node, conf)
  local json_obj = {}

  if not xml_node then
    return nil
  end

  -- Handle attributes
  if xml_node.attr then
    for k, v in pairs(xml_node.attr) do
      if conf.strip_namespaces and k:find(":") then
        k = k:match(".*:(.*)") or k -- remove namespace prefix
      end
      json_obj[conf.attribute_prefix .. k] = v
    end
  end

  -- Handle children
  if xml_node[1] then -- Check if it's a table with children (not just a string value)
    local children_count = {}
    local children_array_check = {} -- To check if a child should be forced into an array

    for i = 1, #xml_node do
      local child = xml_node[i]
      if type(child) == "table" and child.tag then
        local child_tag = child.tag
        if conf.strip_namespaces and child_tag:find(":") then
          child_tag = child_tag:match(".*:(.*)") or child_tag
        end

        children_count[child_tag] = (children_count[child_tag] or 0) + 1

        -- Check for arrays_key_ending
        if conf.arrays_key_ending ~= "" and child_tag:endswith(conf.arrays_key_ending) then
          children_array_check[child_tag] = true
        end
      end
    end

    for i = 1, #xml_node do
      local child = xml_node[i]
      if type(child) == "table" and child.tag then
        local child_tag = child.tag
        if conf.strip_namespaces and child_tag:find(":") then
          child_tag = child_tag:match(".*:(.*)") or child_tag
        end

        local converted_child = xml_to_json_table(child, conf)

        local target_key = child_tag
        if conf.arrays_key_ending_strip and children_array_check[child_tag] then
          target_key = target_key:gsub(conf.arrays_key_ending .. "$", "")
        end

        if children_count[child_tag] > 1 or children_array_check[child_tag] then
          -- This tag appears multiple times or is forced into an array
          if not json_obj[target_key] then
            json_obj[target_key] = {}
          end
          table.insert(json_obj[target_key], converted_child)
        else
          -- This tag appears only once
          json_obj[target_key] = converted_child
        end
      elseif type(child) == "string" and string.len(child) > 0 then
        -- This is text content for the current node (if no children tables exist)
        if next(json_obj) == nil then -- if no attributes or child elements
          return child -- Return raw string if it's just text
        else
          json_obj[conf.text_node_name] = child
        end
      end
    end
  elseif type(xml_node) == "string" and string.len(xml_node) > 0 then
    -- If the xml_node itself is just a string (text content)
    return xml_node
  end

  return json_obj
end

function XMLToJSONHandler:new()
  XMLToJSONHandler.super.new(self, "xml-to-json")
end

function XMLToJSONHandler:access(conf)
  if conf.source == "request" then
    self:transform_body(conf, "request")
  end
end

function XMLToJSONHandler:body_filter(conf)
  if conf.source == "response" then
    self:transform_body(conf, "response")
  end
end

function XMLToJSONHandler:transform_body(conf, phase)
  local body_str
  local content_type_header

  if phase == "request" then
    body_str = kong.request.get_raw_body()
    content_type_header = kong.request.get_header("Content-Type")
  else -- response
    body_str = kong.response.get_raw_body()
    content_type_header = kong.response.get_header("Content-Type")
  end

  if not body_str or #body_str == 0 then
    return
  end

  -- Only transform if Content-Type is XML
  if not content_type_header or not content_type_header:lower():find("xml") then
    return
  end

  local ok, parsed_xml = pcall(function()
    if conf.remove_xml_declaration then
      body_str = body_str:gsub("^%s*<%?xml[^>]*%?>", "")
    end
    return xml.parse(body_str)
  end)

  if not ok then
    kong.log.err("XML parsing error: ", parsed_xml)
    return
  end

  if not parsed_xml then
    kong.log.warn("XML parser returned nil for: ", body_str)
    return
  end

  local json_table = xml_to_json_table(parsed_xml, conf)
  local json_str
  local json_ok

  if conf.pretty_print then
    json_ok, json_str = pcall(cjson.encode_pretty, json_table)
  else
    json_ok, json_str = pcall(cjson.encode, json_table)
  end

  if not json_ok then
    kong.log.err("JSON encoding error: ", json_str)
    return
  end

  if phase == "request" then
    kong.service.request.set_raw_body(json_str)
    kong.service.request.set_header("Content-Type", conf.content_type)
    -- Also update host request header
    kong.request.set_header("Content-Type", conf.content_type)
  else -- response
    kong.response.set_raw_body(json_str)
    kong.response.set_header("Content-Type", conf.content_type)
  end
end

return XMLToJSONHandler
