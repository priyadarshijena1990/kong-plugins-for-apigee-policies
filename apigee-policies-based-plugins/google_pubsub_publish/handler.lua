local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local util = require "kong.tools.utils" -- For base64 encoding

-- Helper to get a value from a JSON table
local function get_json_value(tbl, path)
  if not tbl or not path or path == "" or path == "." then return tbl end
  for part in path:gmatch("[^.]+") do
    if type(tbl) ~= "table" then return nil end
    tbl = tbl[part]
  end
  return tbl
end

-- Generic helper to get a value from various sources
local function get_value_from_source(source_type, source_name)
  if not source_type or not source_name then return nil end
  if source_type == "literal" then return source_name end

  local value
  if source_type == "header" then
    value = kong.request.get_header(source_name)
  elseif source_type == "query" then
    value = kong.request.get_query_arg(source_name)
  elseif source_type == "body" then
    local raw_body = kong.request.get_raw_body()
    if raw_body and raw_body ~= "" then
      local ok, parsed = pcall(cjson.decode, raw_body)
      value = ok and get_json_value(parsed, source_name) or raw_body
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  end
  return value
end

local GooglePubSubPublishHandler = BasePlugin:extend("google-pubsub-publish")
GooglePubSubPublishHandler.PRIORITY = 1000 -- Can be adjusted

function GooglePubSubPublishHandler:new()
  GooglePubSubPublishHandler.super.new(self)
end

-- Core function to publish to Pub/Sub
local function publish_to_pubsub(conf, current_phase)
  local access_token = get_value_from_source(conf.gcp_access_token_source_type, conf.gcp_access_token_source_name)
  if not access_token or access_token == "" then
    local error_msg = "No GCP access token found from source."
    kong.log.err("GooglePubSubPublish: ", error_msg)
    return false, error_msg
  end

  local payload_content = get_value_from_source(conf.message_payload_source_type, conf.message_payload_source_name)
  if not payload_content then
    kong.log.warn("GooglePubSubPublish: No message payload found. Sending empty payload.")
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

  if conf.message_attributes and next(conf.message_attributes) then -- Check if table is not empty
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
    local error_msg = string.format("Failed to publish to Pub/Sub topic '%s'. Error: %s", conf.pubsub_topic_name, err)
    kong.log.err("GooglePubSubPublish: ", error_msg)
    return false, error_msg
  elseif res.status ~= 200 then
    local error_msg = string.format("Pub/Sub API returned error status %d. Body: %s", res.status, res.body)
    kong.log.err("GooglePubSubPublish: ", error_msg)
    return false, error_msg
  else
    kong.log.debug("GooglePubSubPublish: Successfully published message to Pub/Sub topic '", conf.pubsub_topic_name, "'.")
    return true
  end
end


function GooglePubSubPublishHandler:access(conf)
  GooglePubSubPublishHandler.super.access(self)

  if conf.phase == "access" then
    local ok, err_msg = publish_to_pubsub(conf, "access")
    if not ok then
      if not conf.on_error_continue then
        return kong.response.exit(conf.on_error_status, conf.on_error_body)
      end
    end
  end
end

function GooglePubSubPublishHandler:log(conf)
  GooglePubSubPublishHandler.super.log(self)

  if conf.phase == "log" then
    -- Publish asynchronously in log phase
    local ok, timer_err = kong.timer.at(0, function(_, config)
      local _, http_err = publish_to_pubsub(config, "log")
      if http_err then
        kong.log.err("GooglePubSubPublish (async): Failed to publish message: ", http_err)
      end
    end, conf)

    if not ok then
      kong.log.err("GooglePubSubPublish: Failed to create async timer for logging: ", timer_err)
    end
  end
end

return GooglePubSubPublishHandler
