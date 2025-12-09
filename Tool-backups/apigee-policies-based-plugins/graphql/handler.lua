local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local fun = require "kong.tools.functional"

local GraphQLHandler = BasePlugin:extend("graphql")

function GraphQLHandler:new()
  return GraphQLHandler.super.new(self, "graphql")
end

-- Helper to extract GraphQL query string from request body
local function extract_graphql_query(request_body)
  if not request_body or request_body == "" then
    return nil
  end

  local parsed_body, err = cjson.decode(request_body)
  if parsed_body and parsed_body.query then
    return parsed_body.query -- Standard GraphQL JSON format: { "query": "..." }
  end

  -- Assume it's a plain GraphQL query string
  return request_body
end

-- Helper to detect operation type
local function detect_operation_type(query_string)
  if not query_string then return nil end

  local lower_query = query_string:lower()
  if lower_query:find("^%s*mutation") then
    return "mutation"
  elseif lower_query:find("^%s*query") then
    return "query"
  elseif lower_query:find("^%s*subscription") then
    return "subscription"
  end
  return nil
end


function GraphQLHandler:access(conf)
  GraphQLHandler.super.access(self)

  local raw_request_body = kong.request.get_raw_body()
  local graphql_query_string = extract_graphql_query(raw_request_body)

  if not graphql_query_string or graphql_query_string == "" then
    kong.log.debug("GraphQL plugin: No GraphQL query string found. Skipping processing.")
    return -- Let request proceed if no query found
  end

  local operation_type = detect_operation_type(graphql_query_string)

  -- Enforce allowed operation types
  if #conf.allowed_operation_types > 0 then
    if not operation_type then
      kong.log.warn("GraphQL plugin: Operation type not detected. Blocking request.")
      return kong.response.exit(conf.block_status, conf.block_body)
    end

    local is_allowed = false
    for _, allowed_type in ipairs(conf.allowed_operation_types) do
      if allowed_type == operation_type then
        is_allowed = true
        break
      end
    end

    if not is_allowed then
      kong.log.warn("GraphQL plugin: Operation type '", operation_type, "' is not allowed. Blocking request.")
      return kong.response.exit(conf.block_status, conf.block_body)
    end
  end

  -- Check block patterns
  for _, block_pattern in ipairs(conf.block_patterns) do
    local ok, res, err = ngx.re.find(graphql_query_string, block_pattern, "jo")
    if ok and res ~= nil then
      kong.log.warn("GraphQL plugin: Blocking request due to block pattern match: ", block_pattern)
      return kong.response.exit(conf.block_status, conf.block_body)
    elseif not ok then
      kong.log.err("GraphQL plugin: Error applying block pattern '", block_pattern, "'. Error: ", err)
      -- Decide whether to block on regex error or continue. For security, blocking is safer.
      return kong.response.exit(500, "Internal error in GraphQL policy.")
    end
  end

  -- Store operation type in shared context
  if conf.extract_operation_type_to_shared_context_key and operation_type then
    kong.ctx.shared[conf.extract_operation_type_to_shared_context_key] = operation_type
    kong.log.debug("GraphQL plugin: Extracted operation type '", operation_type, "' to shared context key '", conf.extract_operation_type_to_shared_context_key, "'")
  end

  kong.log.debug("GraphQL plugin: GraphQL request processed. Operation type: ", operation_type or "N/A")
end

return GraphQLHandler
