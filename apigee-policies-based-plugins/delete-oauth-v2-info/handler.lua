local cjson = require "cjson"

-- Helper to safely get value from JSON body using simple dot notation
local function get_json_value(json_table, path)
  if not json_table or not path or path == "" then
    return json_table
  end
  
  local current = json_table
  for part in path:gmatch("[^.]+") do
    if type(current) == "table" and current[part] ~= nil then
      current = current[part]
    else
      return nil
    end
  end
  return current
end

-- Helper to get a string value from various request sources
local function get_value_from_source(source_type, source_name)
  local value
  if source_type == "header" then
    value = kong.request.get_header(source_name)
    if value and source_name:lower() == "authorization" and value:lower():sub(1, 7) == "bearer " then
      value = value:sub(8)
    end
  elseif source_type == "query" then
    value = kong.request.get_query_arg(source_name)
  elseif source_type == "body" then
    local raw_body = kong.request.get_raw_body()
    if raw_body and raw_body ~= "" then
      local ok, parsed_body = pcall(cjson.decode, raw_body)
      if ok then
        value = get_json_value(parsed_body, source_name)
      else
        kong.log.warn("DeleteOAuthV2Info: Could not decode request body as JSON for source '", source_name, "'.")
      end
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  end
  return value and tostring(value) or nil
end

local DeleteOAuthV2InfoHandler = {
  PRIORITY = 1000
}

function DeleteOAuthV2InfoHandler:access(conf)
  local token_string = get_value_from_source(conf.token_source_type, conf.token_source_name)

  if not token_string or token_string == "" then
    kong.log.warn("DeleteOAuthV2Info: No token found from source '", conf.token_source_type, ":", conf.token_source_name, "'. No action taken.")
    if not conf.on_error_continue then
      return kong.response.exit(400, { message = "OAuth 2.0 token to be deleted was not found in the request." })
    end
    return
  end

  -- Attempt to delete the token from the database
  -- This assumes the token is stored in plain text, as per Kong's documentation for the oauth2_tokens schema.
  local _, err = kong.db.oauth2_tokens:delete({
    access_token = token_string,
  })

  if err then
    kong.log.err("DeleteOAuthV2Info: Error while deleting token: ", err)
    if not conf.on_error_continue then
      return kong.response.exit(500, { message = "An error occurred while trying to delete the OAuth 2.0 token." })
    end
    return
  end

  kong.log.notice("DeleteOAuthV2Info: Successfully deleted OAuth 2.0 access token.")
end

return DeleteOAuthV2InfoHandler
