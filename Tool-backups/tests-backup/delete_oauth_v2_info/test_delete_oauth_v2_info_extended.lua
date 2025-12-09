-- Extended functional and unit tests for the delete-oauth-v2-info plugin

local handler_module = require("kong.plugins.delete-oauth-v2-info.handler")
local DeleteOAuthV2InfoHandler = handler_module -- The module itself is the handler class

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        ctx = {
            shared = {},
        },
        log = {
            err = function(...) mock_kong.log.err_called = true; mock_kong.log.err_args = {...} end,
            warn = function(...) mock_kong.log.warn_called = true; mock_kong.log.warn_args = {...} end,
            debug = function(...) end, -- Suppress debug logs in tests for cleaner output
        },
        response = {
            exit = function(...) error("Kong response exit called") end,
        },
        -- Mocking super access method as it's called internally
        super = {
          access = function() end,
        }
    }
end

-- Helper function to run a test and ensure no unexpected exits
local function run_test_and_assert_no_exit(test_func)
    local ok, err = pcall(test_func)
    assert(ok, "Test should not call kong.response.exit: " .. tostring(err))
end

-- --- Unit Test: new() method ---
do
    reset_mock_kong()
    local instance = DeleteOAuthV2InfoHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == DeleteOAuthV2InfoHandler, "Instance should have correct metatable")
end

-- --- Scenario 1: Successful deletion of existing keys. ---
do
    reset_mock_kong()
    mock_kong.ctx.shared = {
        oauth_client_id = "123",
        oauth_scope = "read write",
        other_data = "untouched",
    }
    local initial_shared_count = 0
    for k, v in pairs(mock_kong.ctx.shared) do initial_shared_count = initial_shared_count + 1 end

    local conf = {
        keys_to_delete = { "oauth_client_id", "oauth_scope" }
    }
    local instance = DeleteOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)

    assert(mock_kong.ctx.shared["oauth_client_id"] == nil, "oauth_client_id should be deleted")
    assert(mock_kong.ctx.shared["oauth_scope"] == nil, "oauth_scope should be deleted")
    assert(mock_kong.ctx.shared["other_data"] == "untouched", "other_data should remain untouched")
    
    local final_shared_count = 0
    for k, v in pairs(mock_kong.ctx.shared) do final_shared_count = final_shared_count + 1 end
    assert(final_shared_count == 1, "Only one key should remain in shared context")
end

-- --- Scenario 2: Attempted deletion of non-existent keys. ---
do
    reset_mock_kong()
    mock_kong.ctx.shared = {
        existing_key = "value",
    }
    local initial_shared_context = { existing_key = "value" } -- Deep copy for comparison

    local conf = {
        keys_to_delete = { "non_existent_key_1", "non_existent_key_2" }
    }
    local instance = DeleteOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)

    assert(mock_kong.ctx.shared["non_existent_key_1"] == nil, "non_existent_key_1 should still be nil")
    assert(mock_kong.ctx.shared["non_existent_key_2"] == nil, "non_existent_key_2 should still be nil")
    assert(mock_kong.ctx.shared["existing_key"] == "value", "Existing key should not be touched")
    
    -- Verify shared context is effectively unchanged except for logging
    local final_shared_context = {}
    for k, v in pairs(mock_kong.ctx.shared) do final_shared_context[k] = v end
    assert(initial_shared_context.existing_key == final_shared_context.existing_key, "Shared context should remain functionally identical for existing keys")
end

-- --- Scenario 3: Deletion of multiple keys, some existing, some not. ---
do
    reset_mock_kong()
    mock_kong.ctx.shared = {
        key_to_delete_1 = "val1",
        key_to_keep = "val_keep",
        key_to_delete_2 = "val2",
    }

    local conf = {
        keys_to_delete = { "key_to_delete_1", "non_existent_key", "key_to_delete_2" }
    }
    local instance = DeleteOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)

    assert(mock_kong.ctx.shared["key_to_delete_1"] == nil, "key_to_delete_1 should be deleted")
    assert(mock_kong.ctx.shared["key_to_delete_2"] == nil, "key_to_delete_2 should be deleted")
    assert(mock_kong.ctx.shared["non_existent_key"] == nil, "non_existent_key should still be nil")
    assert(mock_kong.ctx.shared["key_to_keep"] == "val_keep", "key_to_keep should remain untouched")
end

-- --- Scenario 4: Configuration with no keys to delete. ---
do
    reset_kong()
    mock_kong.ctx.shared = {
        initial_key_1 = "valA",
        initial_key_2 = "valB",
    }
    local initial_shared_context = { initial_key_1 = "valA", initial_key_2 = "valB" }

    local conf = {
        keys_to_delete = {}
    }
    local instance = DeleteOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)

    assert(mock_kong.ctx.shared["initial_key_1"] == initial_shared_context["initial_key_1"], "initial_key_1 should be untouched")
    assert(mock_kong.ctx.shared["initial_key_2"] == initial_shared_context["initial_key_2"], "initial_key_2 should be untouched")
    assert(mock_kong.log.debug_called, "Debug log for no keys to delete should be called")
    assert(string.find(mock_kong.log.debug_args[1], "No keys configured to delete."), "Debug message should match")
end

-- --- Scenario 5: Verification that other keys in `kong.ctx.shared` are untouched. ---
-- Covered sufficiently by Scenarios 1 and 3 already by asserting `other_data` or `key_to_keep` remains.

print("All delete-oauth-v2-info extended tests passed!")