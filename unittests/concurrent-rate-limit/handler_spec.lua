-- unittests/concurrent-rate-limit/handler_spec.lua

describe("concurrent-rate-limit handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  describe("local policy", function()
    it("should increment and decrement counter", function()
      local local_policy = require "apigee-policies-based-plugins.concurrent-rate-limit.policies.local"
      kong.shared.concurrent_limit_counters = {
        incr = function(key, val)
          if not _G.counters then _G.counters = {} end
          if not _G.counters[key] then _G.counters[key] = 0 end
          _G.counters[key] = _G.counters[key] + val
          return _G.counters[key]
        end
      }

      local policy, err = local_policy.new()
      assert.is_not_nil(policy)

      local new_count, incr_err = policy:increment("mykey", { rate = 10 })
      assert.is_nil(incr_err)
      assert.equal(1, new_count)

      new_count, incr_err = policy:increment("mykey", { rate = 10 })
      assert.equal(2, new_count)

      new_count, decr_err = policy:decrement("mykey")
      assert.is_nil(decr_err)
      assert.equal(1, new_count)
    end)

    it("should return limit exceeded", function()
      local local_policy = require "apigee-policies-based-plugins.concurrent-rate-limit.policies.local"
      _G.counters = {}
      
      local policy, err = local_policy.new()
      assert.is_not_nil(policy)
      
      policy:increment("mykey", { rate = 1 })
      local new_count, incr_err = policy:increment("mykey", { rate = 1 })

      assert.equal("limit exceeded", incr_err)
    end)
  end)

  describe("cluster policy", function()
    it("should increment and decrement counter", function()
      local cluster_policy = require "apigee-policies-based-plugins.concurrent-rate-limit.policies.cluster"
      _G.db_rows = {}
      kong.db = {
        crl_counters = {
          find_one_by_key = function(key)
            return _G.db_rows[key]
          end,
          insert = function(row)
            _G.db_rows[row.key] = row
            return row
          end,
          update = function(query, row)
            _G.db_rows[query.key].value = row.value
            return row
          end
        }
      }

      local policy, err = cluster_policy.new()
      assert.is_not_nil(policy)

      local new_count, incr_err = policy:increment("mykey", { rate = 10 })
      assert.is_nil(incr_err)
      assert.equal(1, new_count)

      new_count, incr_err = policy:increment("mykey", { rate = 10 })
      assert.equal(2, new_count)

      new_count, decr_err = policy:decrement("mykey")
      assert.is_nil(decr_err)
      assert.equal(1, new_count)
    end)
  end)
end)
