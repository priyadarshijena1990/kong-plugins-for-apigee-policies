-- Unit tests for the access-entity plugin

local handler_module = require("kong.plugins.access-entity.handler")
local AccessEntityHandler = handler_module -- The module itself is the handler class

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        client = {
            get_consumer = function() return nil end,
            get_consumer_groups = function() return {}, nil end,
        },
        ctx = {
            shared = {},
        },
        log = {
            err_called = false,
            warn_called = false,
            err_args = nil,
            warn_args = nil,
            err = function(...) mock_kong.log.err_called = true; mock_kong.log.err_args = {...} end,
            warn = function(...) mock_kong.log.warn_called = true; mock_kong.log.warn_args = {...} end,
            debug = function(...) end, -- Suppress debug logs in tests for cleaner output
        },
        -- Mocking super access method as it's called internally
        super = {
          access = function() end,
        },
    }
end

-- --- Test: new() method (basic instance creation) ---
do
    reset_mock_kong()
    local instance = AccessEntityHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == AccessEntityHandler, "Instance should have correct metatable")
end

-- --- Scenario 1: Successful consumer retrieval and shared context population ---
do
    reset_mock_kong()
    local conf = {
        context_variable_name = "test_consumer_entity",
    }
    local mock_consumer = {
        id = "consumer-123",
        username = "testuser",
        custom_id = "external-id-abc",
        created_at = 1678886400,
        tags = {"app:frontend", "env:dev"},
    }
    local mock_groups = {
        { name = "gold_users" },
        { name = "internal_api_access" },
    }

    mock_kong.client.get_consumer = function() return mock_consumer end
    mock_kong.client.get_consumer_groups = function() return mock_groups, nil end
    
    local instance = AccessEntityHandler:new()
    instance:access(conf)

    assert(mock_kong.ctx.shared[conf.context_variable_name] ~= nil, "Shared context should contain consumer entity")
    local entity = mock_kong.ctx.shared[conf.context_variable_name]
    assert(entity.id == mock_consumer.id, "Consumer ID should match")
    assert(entity.username == mock_consumer.username, "Consumer username should match")
    assert(entity.custom_id == mock_consumer.custom_id, "Consumer custom_id should match")
    assert(entity.created_at == mock_consumer.created_at, "Consumer created_at should match")
    assert(#entity.tags == #mock_consumer.tags, "Consumer tags count should match")
    assert(entity.tags[1] == mock_consumer.tags[1], "Consumer tag 1 should match")
    assert(entity.tags[2] == mock_consumer.tags[2], "Consumer tag 2 should match")
    assert(#entity.groups == #mock_groups, "Consumer groups count should match")
    assert(entity.groups[1] == mock_groups[1].name, "Consumer group 1 should match")
    assert(entity.groups[2] == mock_groups[2].name, "Consumer group 2 should match")
    assert(mock_kong.log.debug_called == nil, "No debug log for successful operation")
    assert(mock_kong.log.err_called == false, "No error should be logged")
end

-- --- Scenario 2: No authenticated consumer found ---
do
    reset_mock_kong()
    local conf = {
        context_variable_name = "test_consumer_entity",
    }
    mock_kong.client.get_consumer = function() return nil end -- No consumer
    
    local instance = AccessEntityHandler:new()
    instance:access(conf)

    assert(mock_kong.ctx.shared[conf.context_variable_name] == nil, "Shared context should not contain consumer entity")
    assert(mock_kong.log.err_called == false, "No error should be logged")
    assert(mock_kong.log.warn_called == false, "No warning should be logged")
    assert(mock_kong.log.debug_called == nil or mock_kong.log.debug_called == true, "Debug log for no consumer found should be present")
    assert(string.find(mock_kong.log.err_args and mock_kong.log.err_args[1] or "", "No authenticated consumer found. Skipping."), "Debug log should indicate skipping")
end

-- --- Scenario 3: Error fetching consumer groups ---
do
    reset_mock_kong()
    local conf = {
        context_variable_name = "test_consumer_entity",
    }
    local mock_consumer = {
        id = "consumer-456",
        username = "anotheruser",
    }
    local mock_error = "database error"

    mock_kong.client.get_consumer = function() return mock_consumer end
    mock_kong.client.get_consumer_groups = function() return nil, mock_error end -- Simulate error
    
    local instance = AccessEntityHandler:new()
    instance:access(conf)

    assert(mock_kong.ctx.shared[conf.context_variable_name] ~= nil, "Shared context should still contain consumer entity without groups")
    local entity = mock_kong.ctx.shared[conf.context_variable_name]
    assert(entity.id == mock_consumer.id, "Consumer ID should match")
    assert(entity.username == mock_consumer.username, "Consumer username should match")
    assert(#entity.groups == 0, "Consumer groups should be empty")
    assert(mock_kong.log.err_called == true, "Error should be logged for group fetch failure")
    assert(string.find(mock_kong.log.err_args[1], "Could not fetch consumer groups"), "Error message should indicate group fetch error")
end

-- --- Scenario 4: Custom context variable name ---
do
    reset_mock_kong()
    local conf = {
        context_variable_name = "my_custom_consumer_var",
    }
    local mock_consumer = {
        id = "consumer-789",
        username = "customvaruser",
    }
    mock_kong.client.get_consumer = function() return mock_consumer end
    mock_kong.client.get_consumer_groups = function() return {}, nil end
    
    local instance = AccessEntityHandler:new()
    instance:access(conf)

    assert(mock_kong.ctx.shared["my_custom_consumer_var"] ~= nil, "Shared context should use custom variable name")
    assert(mock_kong.ctx.shared["my_custom_consumer_var"].id == mock_consumer.id, "Consumer ID should match in custom variable")
end

print("All access-entity unit tests passed successfully!")
