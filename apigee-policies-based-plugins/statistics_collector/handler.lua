local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local fun = require "kong.tools.functional"

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
-- In log phase, kong.request functions still work for original request.
local function get_value_from_source(source_type, source_name, phase)
  local value = nil
  if source_type == "header" then
    value = kong.request.get_header(source_name)
  elseif source_type == "query" then
    value = kong.request.get_query_arg(source_name)
  elseif source_type == "path" then
    value = kong.request.get_uri()
  elseif source_type == "body" then
    -- Note: kong.request.get_raw_body() may return nil in log phase if not explicitly buffered
    local raw_body = kong.request.get_raw_body()
    if raw_body then
      local ok, parsed_body = pcall(cjson.decode, raw_body)
      if ok then
        value = get_json_value(parsed_body, source_name)
      else
        kong.log.warn("StatisticsCollector: Could not decode body as JSON for source '", source_name, "'.")
      end
    end
  elseif source_type == "shared_context" then
    value = kong.ctx.shared[source_name]
  elseif source_type == "literal" then
    value = source_name
  end
  return value
end

-- Helper to convert value to specific type
local function convert_value_to_type(value, target_type)
  if value == nil then return nil end

  if target_type == "string" then
    return tostring(value)
  elseif target_type == "number" then
    return tonumber(value)
  elseif target_type == "boolean" then
    if type(value) == "string" then
      local lower_val = value:lower()
      return lower_val == "true"
    elseif type(value) == "boolean" then
      return value
    end
  end
  return value -- Return original if no conversion or type mismatch
end


local StatisticsCollectorHandler = BasePlugin:extend("statistics-collector")

function StatisticsCollectorHandler:new()
  return StatisticsCollectorHandler.super.new(self, "statistics-collector")
end

function StatisticsCollectorHandler:log(conf)
  StatisticsCollectorHandler.super.log(self)

  local collected_statistics = {}
  for _, stat_config in ipairs(conf.statistics_to_collect) do
    -- Use 'access' for get_value_from_source phase argument, as kong.request functions are available
    local value = get_value_from_source(stat_config.source_type, stat_config.source_name, "access")
    if value ~= nil then
      value = convert_value_to_type(value, stat_config.value_type)
      collected_statistics[stat_config.name] = value
    else
      kong.log.debug("StatisticsCollector: Statistic '", stat_config.name, "' value not found from source '", stat_config.source_type, ":", stat_config.source_name, "'.")
    end
  end

  if next(collected_statistics) == nil then -- Check if table is empty
    kong.log.debug("StatisticsCollector: No statistics collected. Skipping call to external service.")
    return
  end

  local callout_opts = {
    method = conf.method,
    headers = conf.headers,
    body = cjson.encode(collected_statistics),
    timeout = conf.timeout,
    connect_timeout = 5000, -- Hardcoded, could be configurable
    ssl_verify = true,      -- Hardcoded, could be configurable
  }

  local res, err = kong.http.client.go(conf.collection_service_url, callout_opts)

  if not res then
    kong.log.err("StatisticsCollector: Failed to send statistics to '", conf.collection_service_url, "'. Error: ", err)
  elseif res.status >= 400 then
    kong.log.warn("StatisticsCollector: Statistics service '", conf.collection_service_url, "' returned error status: ", res.status, " Body: ", res.body)
  else
    kong.log.debug("StatisticsCollector: Successfully sent statistics to '", conf.collection_service_url, "'.")
  end
end

return StatisticsCollectorHandler
