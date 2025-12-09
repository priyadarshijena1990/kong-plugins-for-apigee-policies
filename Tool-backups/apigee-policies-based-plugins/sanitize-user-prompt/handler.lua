local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local html_tags_pattern = "<[^>]*>" -- Simple pattern to remove HTML/XML tags

-- Helper to safely get value from JSON body using simple dot notation
local function get_json_value(json_table, path)
  if not json_table or not path or path == "" then
    return json_table -- Return whole table if path is empty
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

-- Helper to safely set value in JSON body using simple dot notation
local function set_json_value(json_table, path, value)
  if not json_table or not path or path == "" then
    -- If path is empty, we assume the whole body needs to be replaced
    -- This case is handled outside this function by setting the entire table
    return false -- Indicate that this helper cannot handle whole body replacement
  end
  local parts = {}
  for part in path:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  local current = json_table
  for i, part in ipairs(parts) do
    if i == #parts then
      current[part] = value
      return true
    else
      if type(current[part]) ~= "table" then
        current[part] = {} -- Create intermediate table if it doesn't exist
      end
      current = current[part]
    end
  end
  return false -- Should not reach here
end

local SanitizeUserPromptHandler = BasePlugin:extend("sanitize-user-prompt")

function SanitizeUserPromptHandler:new()
  return SanitizeUserPromptHandler.super.new(self, "sanitize-user-prompt")
end

function SanitizeUserPromptHandler:access(conf)
  SanitizeUserPromptHandler.super.access(self)

  local user_prompt = nil
  local request_body = nil
  local parsed_body = nil
  local body_is_modified = false

  -- Step 1: Get the user prompt
  if conf.source_type == "header" then
    user_prompt = kong.request.get_header(conf.source_name)
  elseif conf.source_type == "query" then
    user_prompt = kong.request.get_query_arg(conf.source_name)
  elseif conf.source_type == "body" then
    -- Read body and parse it once
    request_body = kong.request.get_raw_body()
    if request_body then
      local ok, decoded = pcall(cjson.decode, request_body)
      if ok then
        parsed_body = decoded
        user_prompt = get_json_value(parsed_body, conf.source_name)
      else
        kong.log.warn("SanitizeUserPrompt: Could not decode request body as JSON for source. Skipping sanitization.")
        return -- Cannot proceed if body is unparsable
      end
    end
  end

  if not user_prompt then
    kong.log.debug("SanitizeUserPrompt: No user prompt found from source '", conf.source_type, ":", conf.source_name, "'. Skipping sanitization.")
    return
  end

  user_prompt = tostring(user_prompt) -- Ensure it's a string

  -- Step 2: Apply sanitization rules
  local sanitized_prompt = user_prompt

  if conf.trim_whitespace then
    sanitized_prompt = sanitized_prompt:match("^%s*(.-)%s*$") -- Trim leading/trailing whitespace
  end

  if conf.remove_html_tags then
    sanitized_prompt = ngx.re.gsub(sanitized_prompt, html_tags_pattern, "", "jo")
  end

  for _, replacement_rule in ipairs(conf.replacements) do
    local pattern = replacement_rule.pattern
    local replace_with = replacement_rule.replacement
    local ok, res, err = ngx.re.gsub(sanitized_prompt, pattern, replace_with, "jo")
    if ok then
      sanitized_prompt = res
    else
      kong.log.warn("SanitizeUserPrompt: Failed to apply replacement pattern '", pattern, "'. Error: ", err)
    end
  end

  for _, block_pattern in ipairs(conf.block_on_match) do
    local ok, res, err = ngx.re.find(sanitized_prompt, block_pattern, "jo")
    if ok and res ~= nil then
      kong.log.warn("SanitizeUserPrompt: Blocking request due to match with pattern: ", block_pattern)
      return kong.response.exit(conf.block_status, conf.block_body)
    elseif not ok then
      kong.log.warn("SanitizeUserPrompt: Failed to apply block pattern '", block_pattern, "'. Error: ", err)
    end
  end

  if conf.max_length and #sanitized_prompt > conf.max_length then
    sanitized_prompt = sanitized_prompt:sub(1, conf.max_length)
    kong.log.debug("SanitizeUserPrompt: Prompt truncated to max_length: ", conf.max_length)
  end

  -- Step 3: Set the sanitized prompt to the destination
  if conf.destination_type == "header" then
    kong.request.set_header(conf.destination_name, sanitized_prompt)
  elseif conf.destination_type == "query" then
    kong.request.set_query_arg(conf.destination_name, sanitized_prompt)
  elseif conf.destination_type == "body" then
    if not parsed_body then
      -- If original body was empty or not JSON, create a new JSON body
      parsed_body = {}
    end

    if conf.destination_name == "" or conf.destination_name == "." then
      -- Replace entire body
      kong.request.set_body(sanitized_prompt)
      body_is_modified = true
    else
      -- Set specific field in body
      set_json_value(parsed_body, conf.destination_name, sanitized_prompt)
      kong.request.set_body(cjson.encode(parsed_body))
      body_is_modified = true
    end
  elseif conf.destination_type == "shared_context" then
    kong.ctx.shared[conf.destination_name] = sanitized_prompt
  end

  kong.log.debug("SanitizeUserPrompt: Prompt sanitized and set to '", conf.destination_type, ":", conf.destination_name, "'")

  if body_is_modified then
    -- Ensure the body content type is set correctly if body was modified
    kong.request.set_header("Content-Type", "application/json")
  end
end

return SanitizeUserPromptHandler
