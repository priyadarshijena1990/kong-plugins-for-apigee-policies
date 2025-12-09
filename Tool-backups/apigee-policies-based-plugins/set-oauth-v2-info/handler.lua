local BasePlugin = require "kong.plugins.base_plugin"
local fun = require "kong.tools.functional"

local SetOAuthV2InfoHandler = BasePlugin:extend("set-oauth-v2-info")

function SetOAuthV2InfoHandler:new()
  return SetOAuthV2InfoHandler.super.new(self, "set-oauth-v2-info")
end

function SetOAuthV2InfoHandler:access(conf)
  SetOAuthV2InfoHandler.super.access(self)

  local oauth_info = {}

  local consumer = kong.client.get_consumer()
  if consumer and consumer.id then
    oauth_info.consumer_id = consumer.id
    oauth_info.consumer_username = consumer.username or consumer.custom_id
    oauth_info.consumer_custom_id = consumer.custom_id
    -- Add more consumer details if needed
  end

  local credential = kong.client.get_credential()
  if credential then
    oauth_info.client_id = credential.client_id or credential.id
    oauth_info.application_name = credential.name
    -- Add more credential details if needed
  end

  -- Extract custom attributes
  for _, attr_name in ipairs(conf.custom_attributes) do
    if consumer and consumer[attr_name] then
      oauth_info[attr_name] = consumer[attr_name]
    elseif credential and credential[attr_name] then
      oauth_info[attr_name] = credential[attr_name]
    -- You might want to check other places where custom attributes could be stored
    -- For example, in kong.ctx.authenticated_oauth2_token if the OAuth 2.0 plugin is used
    -- or in jwt claims if a JWT plugin is used.
    -- For now, we'll keep it simple and check consumer and credential directly.
    end
  end

  -- Store the extracted information in kong.ctx.shared
  kong.ctx.shared.oauth_v2_info = oauth_info

  kong.log.debug("SetOAuthV2Info plugin: Extracted OAuth2 info: ", fun.json_encode(oauth_info))
end

return SetOAuthV2InfoHandler
