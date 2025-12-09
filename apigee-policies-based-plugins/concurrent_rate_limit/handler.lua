local policies = {
  local_policy = require("kong.plugins.apigee-policies-based-plugins.concurrent-rate-limit.policies.local"),
  cluster_policy = require("kong.plugins.apigee-policies-based-plugins.concurrent-rate-limit.policies.cluster")
}

-- Helper function to get the counter key from various sources
local function get_counter_key(conf)
  local key_value

  if conf.counter_key_source_type == "header" then
    key_value = kong.request.get_header(conf.counter_key_source_name)
  elseif conf.counter_key_source_type == "query" then
    key_value = kong.request.get_query_arg(conf.counter_key_source_name)
  elseif conf.counter_key_source_type == "path" then
    if conf.counter_key_source_name == "." then
      key_value = kong.request.get_uri()
    else
      key_value = conf.counter_key_source_name
    end
  elseif conf.counter_key_source_type == "shared_context" then
    key_value = kong.ctx.shared[conf.counter_key_source_name]
  end

  -- Default to a global key if a specific one isn't found
  return "crl#" .. (key_value and tostring(key_value) or "global")
end

local ConcurrentRateLimitHandler = {
  PRIORITY = 1000,
}

function ConcurrentRateLimitHandler:access(conf)
  -- Dynamically load the policy implementation
  local policy = policies[conf.policy .. "_policy"]
  if not policy then
    kong.log.err("ConcurrentRateLimit: Failed to load policy '", conf.policy, "'")
    return
  end

  local instance, instance_err = policy.new()
  if not instance then
    kong.log.err("ConcurrentRateLimit: Failed to instantiate policy '", conf.policy, "': ", instance_err)
    return
  end

  local counter_key = get_counter_key(conf)

  -- Store the key and policy instance in the context to be used in the log phase
  kong.ctx.shared.crl_key = counter_key
  kong.ctx.shared.crl_policy_instance = instance

  local new_count, incr_err = instance:increment(counter_key, conf)
  if incr_err then
    if incr_err == "limit exceeded" then
      kong.log.warn("ConcurrentRateLimit: Limit exceeded for key '", counter_key, "'. Limit: ", conf.rate)
      return kong.response.exit(conf.on_limit_exceeded_status, conf.on_limit_exceeded_body)
    else
      kong.log.err("ConcurrentRateLimit: Failed to increment counter for key '", counter_key, "': ", incr_err)
      -- Fail open: allow request to proceed if there's a backend error
      return
    end
  end

  kong.log.debug("ConcurrentRateLimit: Counter for key '", counter_key, "' is at ", new_count)
end

function ConcurrentRateLimitHandler:log(conf)
  local counter_key = kong.ctx.shared.crl_key
  local instance = kong.ctx.shared.crl_policy_instance

  if not instance or not counter_key then
    kong.log.warn("ConcurrentRateLimit: No policy instance or counter key found in context for log phase. Cannot decrement.")
    return
  end

  local _, decr_err = instance:decrement(counter_key)
  if decr_err then
    kong.log.err("ConcurrentRateLimit: Failed to decrement counter for key '", counter_key, "': ", decr_err)
  else
    kong.log.debug("ConcurrentRateLimit: Counter for key '", counter_key, "' decremented.")
  end
end

return ConcurrentRateLimitHandler
