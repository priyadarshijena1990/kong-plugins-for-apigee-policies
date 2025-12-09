-- apigee-policies-based-plugins/concurrent-rate-limit/policies/local.lua

local counters = kong.shared.concurrent_limit_counters

local _M = {}

function _M.new()
  if not counters then
    kong.log.err("ConcurrentRateLimit (local policy): Shared dictionary 'concurrent_limit_counters' is not configured in nginx.conf. The plugin will not work.")
    return nil, "Shared dictionary 'concurrent_limit_counters' not found."
  end
  return {}
end

function _M.increment(self, key, conf)
  if not counters then
    return nil, "Shared dictionary not available"
  end

  local current_count, err = counters:incr(key, 1)
  if not current_count then
    return nil, err
  end

  if current_count > conf.rate then
    -- limit exceeded, decrement back
    counters:incr(key, -1)
    return nil, "limit exceeded"
  end

  return current_count, nil
end

function _M.decrement(self, key)
  if not counters then
    return nil, "Shared dictionary not available"
  end
  return counters:incr(key, -1)
end

return _M
