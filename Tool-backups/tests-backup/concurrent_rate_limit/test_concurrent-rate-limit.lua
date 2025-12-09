-- Unit tests for the concurrent-rate-limit plugin

local handler_module = require("kong.plugins.concurrent-rate-limit.handler")
local ConcurrentRateLimitHandler = handler_module

-- Mock dependencies
local mock_kong = {}
local mock_counter = {}

local function reset_mocks()
    mock_counter = {
        value = 0,
        incr = function(self, key, val)
            self.value = self.value + val
            return self.value
        end,
    }

    mock_kong = {
        client = {
            get_ip = function() return "127.0.0.1" end,
            get_consumer = function() return { id = "consumer-1" } end,
        },
        response = {
            exit_called = false,
            exit_args = {},
            exit = function(status, body)
                mock_kong.response.exit_called = true
                mock_kong.response.exit_args = { status = status, body = body }
                error("kong.response.exit called")
            end,
        },
        ctx = {
            plugin = {},
        },
        log = {
            err = function(...) end,
            warn = function(...) end,
        },
        shared = {
            concurrency_counters = mock_counter,
        },
    }
    _G.kong = mock_kong
end

local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(ok or string.find(err, "kong.response.exit called"), "Test should either pass or simulate Kong exit")
end

-- --- Test Suite ---

describe("concurrent-rate-limit handler", function()

    before_each(reset_mocks)

    it("Scenario 1: should allow request when under limit", function()
        local conf = {
            limit = 5,
            counter_name = "concurrency_counters",
            identifier = "global",
        }
        mock_counter.value = 3 -- Simulate 3 active connections

        local instance = ConcurrentRateLimitHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.falsy(mock_kong.response.exit_called, "Should not exit when under the limit")
        assert.are.equal(4, mock_counter.value, "Counter should be incremented")
        assert.is_not_nil(mock_kong.ctx.plugin.concurrent_limit_key, "Context should store the counter key")

        -- Simulate log phase
        instance:log(conf)
        assert.are.equal(3, mock_counter.value, "Counter should be decremented in log phase")
    end)

    it("Scenario 2: should reject request when at limit", function()
        local conf = {
            limit = 2,
            counter_name = "concurrency_counters",
            identifier = "global",
            fault_status = 503,
            fault_message = "Limit reached",
        }
        mock_counter.value = 2 -- Simulate 2 active connections, which is the limit

        local instance = ConcurrentRateLimitHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.truthy(mock_kong.response.exit_called, "Should exit when at the limit")
        assert.are.equal(503, mock_kong.response.exit_args.status)
        assert.are.equal("Limit reached", mock_kong.response.exit_args.body.message)
        -- The counter is incremented to 3, found to be > 2, then decremented back to 2
        assert.are.equal(2, mock_counter.value, "Counter should be restored after rejection")
    end)

    it("Scenario 3: should use IP as identifier", function()
        local conf = {
            limit = 10,
            counter_name = "concurrency_counters",
            identifier = "ip",
        }
        mock_kong.client.get_ip = function() return "192.168.1.100" end

        local instance = ConcurrentRateLimitHandler:new()
        run_test_and_catch_exit(function() instance:access(conf) end)

        assert.falsy(mock_kong.response.exit_called)
        assert.are.equal("concurrency_counters:192.168.1.100", mock_kong.ctx.plugin.concurrent_limit_key)

        -- Simulate log phase
        instance:log(conf)
        assert.are.equal(0, mock_counter.value, "Counter should be decremented")
    end)
end)