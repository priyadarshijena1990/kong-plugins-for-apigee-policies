-- Extended functional and unit tests for the access-entity plugin

local handler_module = require("kong.plugins.access-entity.handler")
local AccessEntityHandler = handler_module.AccessEntityHandler -- Get the class from the module

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        client = {
            get_consumer = function() return nil end,
            get_credential = function() return nil end,
        },
        ctx = {
            shared = {},
        },
        log = {
            warn = function(...) mock_kong.log.warn_called = true; mock_kong.log.warn_args = {...} end,
            debug = function(...) end, -- Suppress debug logs in tests for cleaner output
        },
        -- Mocking super access method as it's called internally
        super = {
          access = function() end
        }
    }
end

-- Before each test, reset the mock Kong environment
reset_mock_kong()

-- Test Scenario 1: No authenticated consumer or credential
-- Should log a warning and not modify kong.ctx.shared
do
    reset_mock_kong() -- Ensure clean state for this specific test
    local conf = {
        entity_type = "consumer",
        extract_attributes = {
            { source_field = "username", output_key = "user_name" }
        }
    }
    local instance = AccessEntityHandler:new() -- Create an instance for the test
    instance:access(conf)

    assert(mock_kong.log.warn_called, "Warning should be logged when no consumer is found")
    assert(string.find(mock_kong.log.warn_args[1], "No authenticated 'consumer' found"), "Warning message should indicate no consumer found")
    assert(#next(mock_kong.ctx.shared) == 0, "kong.ctx.shared should be empty when no entity is found")
end

-- Test Scenario 2: Multiple attribute extraction from consumer
do
    reset_mock_kong()
    local conf = {
        entity_type = "consumer",
        extract_attributes = {
            { source_field = "username", output_key = "user_name" },
            { source_field = "custom_id", output_key = "customer_id" },
            { source_field = "email", output_key = "consumer_email", default_value = "default@example.com" }
        }
    }
    mock_kong.client.get_consumer = function()
        return {
            username = "multi_user",
            custom_id = "abc-123",
            created_at = 123456789 -- This field is not requested, should be ignored
        }
    end
    
    local instance = AccessEntityHandler:new()
    instance:access(conf)

    assert(mock_kong.ctx.shared["user_name"] == "multi_user", "Should extract username")
    assert(mock_kong.ctx.shared["customer_id"] == "abc-123", "Should extract custom_id")
    assert(mock_kong.ctx.shared["consumer_email"] == "default@example.com", "Should use default for missing email")
    assert(mock_kong.ctx.shared["created_at"] == nil, "Should not store unrequested attributes")
end

-- Test Scenario 3: Source field not found, no default value provided
do
    reset_mock_kong()
    local conf = {
        entity_type = "consumer",
        extract_attributes = {
            { source_field = "nonexistent_field", output_key = "should_not_exist" }
        }
    }
    mock_kong.client.get_consumer = function()
        return { username = "user_with_no_field" }
    end
    
    local instance = AccessEntityHandler:new()
    instance:access(conf)

    assert(mock_kong.ctx.shared["should_not_exist"] == nil, "Attribute with no source field and no default should not be stored")
end

-- Test Scenario 4: Extracting a numerical attribute
do
    reset_mock_kong()
    local conf = {
        entity_type = "credential",
        extract_attributes = {
            { source_field = "rate_limit", output_key = "api_rate_limit" }
        }
    }
    mock_kong.client.get_credential = function()
        return {
            key = "api-key-123",
            rate_limit = 100
        }
    end
    
    local instance = AccessEntityHandler:new()
    instance:access(conf)

    assert(mock_kong.ctx.shared["api_rate_limit"] == 100, "Should extract numerical attribute correctly")
end

-- Test Scenario 5: Extracting a boolean attribute
do
    reset_mock_kong()
    local conf = {
        entity_type = "consumer",
        extract_attributes = {
            { source_field = "is_active", output_key = "consumer_is_active" }
        }
    }
    mock_kong.client.get_consumer = function()
        return {
            username = "active_user",
            is_active = true
        }
    end
    
    local instance = AccessEntityHandler:new()
    instance:access(conf)

    assert(mock_kong.ctx.shared["consumer_is_active"] == true, "Should extract boolean attribute correctly")
end

-- Unit Test: new() method
do
    local instance = AccessEntityHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == AccessEntityHandler, "Instance should have correct metatable")
end

print("All access-entity extended tests passed!")
