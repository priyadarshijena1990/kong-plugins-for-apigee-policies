local BasePlugin = require "kong.plugins.base_plugin"

-- Helper to safely get a nested value from a table using dot notation
local function get_nested_value(tbl, path)
  if not tbl or not path or path == "" then
    return nil
  end
  local parts = {}
  for part in path:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  local current = tbl
  for _, part in ipairs(parts) do
    if type(current) == "table" and current[part] ~= nil then
      current = current[part]
    else
      return nil -- Path not found
    end
  end
  return current
end

local GetOAuthV2InfoHandler = BasePlugin:extend("get-oauth-v2-info")
GetOAuthV2InfoHandler.PRIORITY = 1000

function GetOAuthV2InfoHandler:new()
  GetOAuthV2InfoHandler.super.new(self)
end

function GetOAuthV2InfoHandler:access(conf)
  GetOAuthV2InfoHandler.super.access(self)

  local consumer = kong.client.get_consumer()
  local credential = kong.client.get_credential()

  if not consumer or not credential then
    kong.log.warn("GetOAuthV2Info: No authenticated consumer or credential found. This plugin should run after an authentication plugin like OAuth2 or JWT.")
    return
  end

  -- Extract client ID
  if conf.extract_client_id_to_shared_context_key then
    -- For oauth2, the credential is the application, and client_id is a field on it.
    local client_id = credential.client_id or credential.id
    if client_id then
      kong.ctx.shared[conf.extract_client_id_to_shared_context_key] = client_id
      kong.log.debug("GetOAuthV2Info: Extracted client_id '", client_id, "'")
    end
  end

  -- Extract application name
  if conf.extract_app_name_to_shared_context_key then
    local app_name = credential.name
    if app_name then
      kong.ctx.shared[conf.extract_app_name_to_shared_context_key] = app_name
      kong.log.debug("GetOAuthV2Info: Extracted app_name '", app_name, "'")
    end
  end

  -- Extract end user identifier
  if conf.extract_end_user_to_shared_context_key then
    -- The consumer represents the end user in some OAuth2 grant types
    local end_user = consumer.username or consumer.custom_id
    if end_user then
      kong.ctx.shared[conf.extract_end_user_to_shared_context_key] = end_user
      kong.log.debug("GetOAuthV2Info: Extracted end_user '", end_user, "'")
    end
  end

  -- Extract scopes
  if conf.extract_scopes_to_shared_context_key then
    -- The OAuth2 plugin sets this header on the request to the upstream.
    -- It may also be available in the context for subsequent plugins.
    local scopes = kong.request.get_header("X-Authenticated-Scope") or kong.ctx.authenticated_scope
    if scopes then
      -- scopes can be a table or a string, ensure it's a string
      if type(scopes) == "table" then
        scopes = table.concat(scopes, " ")
      end
      kong.ctx.shared[conf.extract_scopes_to_shared_context_key] = scopes
      kong.log.debug("GetOAuthV2Info: Extracted scopes '", scopes, "'")
    end
  end

  -- Extract custom attributes
  if conf.extract_custom_attributes then
    for _, attr_mapping in ipairs(conf.extract_custom_attributes) do
      -- Try to find the attribute in the consumer's custom_id, or the credential's metadata
      local extracted_value = get_nested_value(consumer, attr_mapping.source_field)
      if extracted_value == nil then
        extracted_value = get_nested_value(credential, attr_mapping.source_field)
      end

      if extracted_value ~= nil then
        kong.ctx.shared[attr_mapping.output_key] = extracted_value
        kong.log.debug("GetOAuthV2Info: Extracted custom attribute '", attr_mapping.source_field, "'")
      end
    end
  end

  kong.log.debug("GetOAuthV2Info: OAuth2 information extraction complete.")
end

return GetOAuthV2InfoHandler
