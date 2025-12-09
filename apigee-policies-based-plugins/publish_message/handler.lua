local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local fun = require "kong.tools.functional"
local util = require "kong.tools.utils" -- For base64 encoding

-- Helper to safely get value from JSON body using simple dot notation
local function get_json_value(json_table, path)
  if not json_table or not path or path == "" then
    return json_table -- Return whole table if path is empty/root
  end
  local parts = {}
  for part in path:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  local current = json_table
  for _, part in ipairs(parts) do
    if type(current) == "table" and current[part] ~= nil then
      current = current[part]
    else
      return nil -- Path not found
    end
  end
  return current
end

-- Helper to get a string value from various sources
local function get_value_from_source(source_type, source_name)
  local value = nil
  if source_type == "header" then
    value = kong.request.get_header(source_name)
  elseif source_type == "query" then
    value = kong.request.get_query_arg(source_name)
  elseif source_type == "body" then
    local raw_body = kong.request.get_raw_body()
    if raw_body then
      local ok, parsed_body = pcall(cjson.decode, raw_body)
      if ok then
        value = get_json_value(parsed_body, source_name)
      else
        kong.log.warn("PublishMessage: Could not decode request body as JSON for source '", source_name, "'.")
      end
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  elseif source_type == "literal" then
    value = source_name
  end
  return value
end


local PublishMessageHandler = BasePlugin:extend("publish-message")

function PublishMessageHandler:new()
  return PublishMessageHandler.super.new(self, "publish-message")
end

function PublishMessageHandler:log(conf)
  PublishMessageHandler.super.log(self)

  local access_token = get_value_from_source(conf.gcp_access_token_source_type, conf.gcp_access_token_source_name)
  if not access_token or access_token == "" then
    kong.log.err("PublishMessage: No GCP access token found from source '", conf.gcp_access_token_source_type, ":", conf.gcp_access_token_source_name, "'. Cannot publish message.")
    -- In log phase, cannot exit with client error. Just log and continue.
    return
  end

  local payload_content = get_value_from_source(conf.message_payload_source_type, conf.message_payload_source_name)
  if not payload_content then
    kong.log.warn("PublishMessage: No message payload found from source '", conf.message_payload_source_type, ":", (conf.message_payload_source_name or "literal"), "'. Sending empty payload.")
    payload_content = ""
  end

  local pubsub_api_url = string.format(
    "https://pubsub.googleapis.com/v1/projects/%s/topics/%s:publish",
    conf.gcp_project_id,
    conf.pubsub_topic_name
  )

  local message_body = {
    messages = {
      {
        data = util.encode_base64(tostring(payload_content)),
      }
    }
  }

  if next(conf.message_attributes) then -- Check if table is not empty
    message_body.messages[1].attributes = conf.message_attributes
  end

  local callout_opts = {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. access_token,
    },
    body = cjson.encode(message_body),
    timeout = 10000,
    connect_timeout = 5000,
    ssl_verify = true,
  }

  local res, err = kong.http.client.go(pubsub_api_url, callout_opts)

  if not res then
    kong.log.err("PublishMessage: Failed to publish to Pub/Sub topic '", conf.pubsub_topic_name, "'. Error: ", err)
  elseif res.status ~= 200 then
    kong.log.err("PublishMessage: Pub/Sub API returned error status: ", res.status, " Body: ", res.body)
  else
    kong.log.debug("PublishMessage: Successfully published message to Pub/Sub topic '", conf.pubsub_topic_name, "'.")
  end
end

return PublishMessageHandler
