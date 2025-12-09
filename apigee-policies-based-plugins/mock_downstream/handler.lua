local MockDownstreamHandler = {
  PRIORITY = 0,
}

function MockDownstreamHandler:header_filter(conf)
  local consumer_entity = kong.ctx.shared.consumer_entity
  if consumer_entity then
    kong.response.set_header("X-Consumer-Id", consumer_entity.id)
    kong.response.set_header("X-Consumer-Username", consumer_entity.username)
    kong.response.set_header("X-Consumer-Groups", table.concat(consumer_entity.groups, ","))
  end

  local subject = kong.ctx.shared.subject
  if subject then
    kong.response.set_header("X-Subject", subject)
  end
end

return MockDownstreamHandler
