-- apigee-policies-based-plugins/concurrent-rate-limit/policies/cluster.lua

local _M = {}

local function log_race_condition_warning()
  kong.log.warn("ConcurrentRateLimit (cluster policy): This policy has a potential race condition under high load. A future version should use atomic database operations.")
end

function _M.new()
  if not kong.db or not kong.db.crl_counters then
    kong.log.err("ConcurrentRateLimit (cluster policy): The 'crl_counters' table is not available in the database. Did you run the migrations?")
    return nil, "DAO for 'crl_counters' not found."
  end
  log_race_condition_warning()
  return {}
end

-- This implementation is not atomic and has a race condition.
-- Two requests could read the same value before either of them updates it.
function _M.increment(self, key, conf)
  local row, err = kong.db.crl_counters:find_one_by_key(key)
  if err then
    return nil, "Database error finding key: " .. err
  end

  local current_count = 0
  if row then
    current_count = row.value
  end

  if current_count >= conf.rate then
    return nil, "limit exceeded"
  end

  -- Increment the count
  local new_count = current_count + 1

  if row then
    -- Update existing row
    local _, update_err = kong.db.crl_counters:update({ key = key }, { value = new_count })
    if update_err then
      return nil, "Database error updating count: " .. update_err
    end
  else
    -- Insert new row
    local _, insert_err = kong.db.crl_counters:insert({ key = key, value = new_count })
    if insert_err then
      return nil, "Database error inserting count: " .. insert_err
    end
  end

  return new_count, nil
end

function _M.decrement(self, key)
  local row, err = kong.db.crl_counters:find_one_by_key(key)
  if err then
    kong.log.err("ConcurrentRateLimit (cluster policy): Failed to find key '", key, "' for decrement: ", err)
    return nil, err
  end

  if not row then
    kong.log.warn("ConcurrentRateLimit (cluster policy): Key '", key, "' not found for decrement. This might indicate a counter mismatch.")
    return nil, "key not found"
  end

  local new_count = row.value - 1
  if new_count < 0 then
    -- This should not happen in normal operation
    new_count = 0
  end

  local _, update_err = kong.db.crl_counters:update({ key = key }, { value = new_count })
  if update_err then
    kong.log.err("ConcurrentRateLimit (cluster policy): Failed to decrement count for key '", key, "': ", update_err)
    return nil, update_err
  end

  return new_count, nil
end

return _M
