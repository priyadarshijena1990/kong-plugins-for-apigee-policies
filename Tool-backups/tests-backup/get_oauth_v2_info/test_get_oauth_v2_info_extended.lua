-- Extended functional and unit tests for the get-oauth-v2-info plugin

local handler_module = require("kong.plugins.get-oauth-v2-info.handler")
local GetOAuthV2InfoHandler = handler_module -- The module itself is the handler class

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        client = {
            get_consumer = function() return nil end,
            get_credential = function() return nil end,
        },
        ctx = {
            shared = {},
            authenticated_oauth2_token = nil,
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
    local instance = GetOAuthV2InfoHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == GetOAuthV2InfoHandler, "Instance should have correct metatable")
end

-- --- Scenario 1: Full successful extraction. ---
do
    reset_mock_kong()
    mock_kong.client.get_consumer = function() return { id = "c1", username = "test_user", custom_id = "eu123" } end
    mock_kong.client.get_credential = function() return { id = "cred1", client_id = "client_abc", name = "TestApp" } end
    mock_kong.ctx.authenticated_oauth2_token = { scope = { "read", "write" }, client_id = "client_abc" }

    local conf = {
        extract_client_id_to_shared_context_key = "clientid",
        extract_app_name_to_shared_context_key = "application_name",
        extract_end_user_to_shared_context_key = "enduser",
        extract_scopes_to_shared_context_key = "oauth_scopes",
        extract_custom_attributes = {
            { source_field = "custom_id", output_key = "consumer_custom_id" },
            { source_field = "id", output_key = "credential_id" },
        },
    }
    local instance = GetOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)

    assert(mock_kong.ctx.shared["clientid"] == "client_abc", "clientid should be extracted")
    assert(mock_kong.ctx.shared["application_name"] == "TestApp", "application_name should be extracted")
    assert(mock_kong.ctx.shared["enduser"] == "test_user", "enduser should be extracted (username preferred)")
    assert(mock_kong.ctx.shared["oauth_scopes"] == "read,write", "oauth_scopes should be extracted and concatenated")
    assert(mock_kong.ctx.shared["consumer_custom_id"] == "eu123", "consumer_custom_id should be extracted")
    assert(mock_kong.ctx.shared["credential_id"] == "cred1", "credential_id should be extracted")
end

-- --- Scenario 2: No authenticated consumer/credential. ---
do
    reset_mock_kong()
    -- kong.client.get_consumer() and get_credential() return nil by default
    local conf = {
        extract_client_id_to_shared_context_key = "clientid",
        extract_end_user_to_shared_context_key = "enduser",
    }
    local instance = GetOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)

    assert(mock_kong.ctx.shared["clientid"] == nil, "clientid should not be set when no credential")
    assert(mock_kong.ctx.shared["enduser"] == nil, "enduser should not be set when no consumer")
    assert(next(mock_kong.ctx.shared) == nil, "Shared context should be empty")
end

-- --- Scenario 3: Missing specific fields (e.g., credential.client_id, but credential.id present). ---
do
    reset_mock_kong()
    mock_kong.client.get_credential = function() return { id = "fallback_cred_id", name = "FallbackApp" } end
    local conf = {
        extract_client_id_to_shared_context_key = "clientid", -- Should use credential.id
    }
    local instance = GetOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)
    assert(mock_kong.ctx.shared["clientid"] == "fallback_cred_id", "Should fallback to credential.id for client_id")
end

-- --- Scenario 4: extract_scopes_to_shared_context_key with scopes as a table. ---
do
    reset_mock_kong()
    mock_kong.ctx.authenticated_oauth2_token = { scope = { "profile", "email", "address" } }
    local conf = { extract_scopes_to_shared_context_key = "oauth_scopes_table" }
    local instance = GetOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)
    assert(mock_kong.ctx.shared["oauth_scopes_table"] == "profile,email,address", "Scopes from table should be comma-separated")
end

-- --- Scenario 5: extract_scopes_to_shared_context_key with scopes as a string. ---
do
    reset_mock_kong()
    mock_kong.ctx.authenticated_oauth2_token = { scope = "read:data,write:data" }
    local conf = { extract_scopes_to_shared_context_key = "oauth_scopes_string" }
    local instance = GetOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)
    assert(mock_kong.ctx.shared["oauth_scopes_string"] == "read:data,write:data", "Scopes from string should be stored as is")
end

-- --- Scenario 6: extract_scopes_to_shared_context_key when no scopes are present. ---
do
    reset_mock_kong()
    mock_kong.ctx.authenticated_oauth2_token = { } -- No scope field
    local conf = { extract_scopes_to_shared_context_key = "oauth_scopes_missing" }
    local instance = GetOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)
    assert(mock_kong.ctx.shared["oauth_scopes_missing"] == nil, "No scope should be extracted if not present")
end

-- --- Scenario 7: Mixed extraction - some configured, some not present. ---
do
    reset_mock_kong()
    mock_kong.client.get_consumer = function() return { username = "mixed_user" } end
    mock_kong.client.get_credential = function() return { client_id = "mixed_client" } end -- No name field
    local conf = {
        extract_app_name_to_shared_context_key = "app_name_missing", -- Credential has no name
        extract_end_user_to_shared_context_key = "mixed_enduser",
        extract_custom_attributes = {
            { source_field = "custom_field_on_consumer", output_key = "consumer_custom" }, -- Missing on consumer
            { source_field = "client_id", output_key = "credential_clientid" }, -- Present on credential
        }
    }
    local instance = GetOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)

    assert(mock_kong.ctx.shared["app_name_missing"] == nil, "app_name should be nil if missing from credential")
    assert(mock_kong.ctx.shared["mixed_enduser"] == "mixed_user", "enduser should be extracted")
    assert(mock_kong.ctx.shared["consumer_custom"] == nil, "consumer_custom should be nil if missing from consumer")
    assert(mock_kong.ctx.shared["credential_clientid"] == "mixed_client", "credential_clientid should be extracted")
end


-- --- Scenario 8: Empty configuration. ---
do
    reset_mock_kong()
    mock_kong.ctx.shared = { existing_key = "existing_value" }
    local conf = {} -- Empty config
    local instance = GetOAuthV2InfoHandler:new()
    run_test_and_assert_no_exit(function() instance:access(conf) end)
    assert(mock_kong.ctx.shared["existing_key"] == "existing_value", "Shared context should be untouched with empty config")
    assert(mock_kong.log.debug_called, "Debug log for completion should be called")
end

print("All get-oauth-v2-info extended tests passed!")