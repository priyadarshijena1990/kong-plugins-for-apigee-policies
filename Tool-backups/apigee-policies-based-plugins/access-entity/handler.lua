local kong = require "kong"

local AccessEntityHandler = {}

AccessEntityHandler.PRIORITY = 1005 -- Runs after authentication plugins
AccessEntityHandler.VERSION = kong.version

function AccessEntityHandler:access(conf)
  local consumer = kong.client.get_consumer()

  if not consumer then
    kong.log.debug("Access Entity: No authenticated consumer found. Skipping.")
    return
  end

  local entity = {
    id = consumer.id,
    username = consumer.username,
    custom_id = consumer.custom_id,
    created_at = consumer.created_at,
    tags = consumer.tags,
    groups = {},
  }

  -- Fetch consumer groups
  local consumer_groups, err = kong.consumer.get_groups(consumer)
  if err then
    kong.log.err("Access Entity: Could not fetch consumer groups: ", err)
  elseif consumer_groups then
    for _, group in ipairs(consumer_groups) do
      table.insert(entity.groups, group.name)
    end
  end

  kong.ctx.shared[conf.context_variable_name] = entity
end

return AccessEntityHandler