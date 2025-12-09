-- Extended functional and unit tests for the graphql plugin

local handler_module = require("kong.plugins.graphql.handler")
local GraphQLHandler = handler_module -- The module itself is the handler class
local cjson = require "cjson"

local mock_kong = {}
local function reset_mock_kong()
    mock_kong = {
        request = {
            get_raw_body = function(...) return nil end,
        },
        ctx = {
            shared = {},
        },
        log = {
            err = function(...) mock_kong.log.err_called = true; mock_kong.log.err_args = {...} end,
            warn = function(...) mock_kong.log.warn_called = true; mock_kong.log.warn_args = {...} end,
            debug = function(...) end, -- Suppress debug logs in tests for cleaner output
        },
        response = {
            exit_called = false,
            exit_args = {},
            exit = function(status_code, body)
                mock_kong.response.exit_called = true
                mock_kong.response.exit_args = { status = status_code, body = body }
                error("Kong response exit called") -- Simulate Kong exiting the request
            end,
        },
        -- Mocking super access method as it's called internally
        super = {
          access = function() end,
        }
    }
end

-- Mock ngx.re functions
gx = ngx or {}
gx.re = {
  find = function(subject, pattern, flags)
    -- Simple mock for ngx.re.find
    local success, result = pcall(string.find, subject, pattern)
    if not success then
      return nil, nil, result -- return nil, nil, error_message for regex errors
    end
    if result then
      return 1, { result } -- Simulate a match
    end
    return 0, nil -- No match
  end,
  match = function(subject, pattern, flags)
    -- Not directly used in handler, but for completeness or future
    return ngx.re.find(subject, pattern, flags)
  end,
}


-- Helper function to run a test and catch the simulated exit error
local function run_test_and_catch_exit(test_func)
    local ok, err = pcall(test_func)
    assert(not ok and string.find(err, "Kong response exit called") or ok, "Test should either pass or simulate Kong exit")
end

-- --- Unit Test: new() method ---
do
    reset_mock_kong()
    local instance = GraphQLHandler:new()
    assert(instance ~= nil, "Handler instance should be created")
    assert(getmetatable(instance).__index == GraphQLHandler, "Instance should have correct metatable")
end

-- --- Scenario 1: Successful GraphQL query, operation type extraction. ---
do
    reset_mock_kong()
    local conf = {
        allowed_operation_types = { "query" },
        extract_operation_type_to_shared_context_key = "graphql_op_type",
    }
    local graphql_json_body = cjson.encode({ query = "query MyQuery { user(id: 1) { name } }" })
    mock_kong.request.get_raw_body = function() return graphql_json_body end
    
    local instance = GraphQLHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit for allowed query")
    assert(mock_kong.ctx.shared["graphql_op_type"] == "query", "Operation type should be extracted as 'query'")
end

-- --- Scenario 2: Successful GraphQL mutation, operation type extraction. ---
do
    reset_mock_kong()
    local conf = {
        allowed_operation_types = { "mutation" },
        extract_operation_type_to_shared_context_key = "graphql_op_type",
    }
    local graphql_plain_body = "mutation AddUser { addUser(name: \"Test\") { id } }"
    mock_kong.request.get_raw_body = function() return graphql_plain_body end
    
    local instance = GraphQLHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit for allowed mutation")
    assert(mock_kong.ctx.shared["graphql_op_type"] == "mutation", "Operation type should be extracted as 'mutation'")
end

-- --- Scenario 3: Blocking by allowed_operation_types (mutation not allowed). ---
do
    reset_mock_kong()
    local conf = {
        allowed_operation_types = { "query" },
        block_status = 403, block_body = "Mutation Not Allowed",
    }
    local graphql_plain_body = "mutation AddUser { addUser(name: \"Test\") { id } }"
    mock_kong.request.get_raw_body = function() return graphql_plain_body end
    
    local instance = GraphQLHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit for disallowed mutation")
    assert(mock_kong.response.exit_args.status == 403, "Status should be 403")
    assert(mock_kong.response.exit_args.body == "Mutation Not Allowed", "Body should match config")
    assert(mock_kong.log.warn_called, "Warning should be logged for disallowed operation type")
end

-- --- Scenario 4: Blocking by block_patterns (malicious string). ---
do
    reset_mock_kong()
    local conf = {
        block_patterns = { "DROP TABLE", "DELETE FROM" },
        block_status = 400, block_body = "Malicious Query Detected",
    }
    local graphql_json_body = cjson.encode({ query = "query { sensitiveData(arg: \"DROP TABLE users\") }" })
    mock_kong.request.get_raw_body = function() return graphql_json_body end
    
    local instance = GraphQLHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit for block pattern match")
    assert(mock_kong.response.exit_args.status == 400, "Status should be 400")
    assert(mock_kong.response.exit_args.body == "Malicious Query Detected", "Body should match config")
    assert(mock_kong.log.warn_called, "Warning should be logged for block pattern")
end

-- --- Scenario 5: Multiple block_patterns (one matches). ---
do
    reset_mock_kong()
    local conf = {
        block_patterns = { "CREATE", "DELETE FROM" },
        block_status = 400, block_body = "Blocked",
    }
    local graphql_plain_body = "query { data(filter: \"DELETE FROM entries\") }"
    mock_kong.request.get_raw_body = function() return graphql_plain_body end
    
    local instance = GraphQLHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit for multiple block pattern match")
    assert(mock_kong.log.warn_called, "Warning should be logged for block pattern")
end

-- --- Scenario 6: No GraphQL query string found in request body. ---
do
    reset_mock_kong()
    local conf = {
        allowed_operation_types = { "query" }, -- Configured, but no query to check
    }
    mock_kong.request.get_raw_body = function() return "" end -- Empty body
    
    local instance = GraphQLHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called == false, "Should not exit if no GraphQL query is found")
    assert(mock_kong.log.debug_called, "Debug log for no query should be called")
    assert(string.find(mock_kong.log.debug_args[1], "No GraphQL query string found"), "Debug message should match")
end

-- --- Scenario 7: Operation type not explicitly detected, allowed_operation_types configured. ---
do
    reset_mock_kong()
    local conf = {
        allowed_operation_types = { "query" },
        block_status = 400, block_body = "Operation Type Missing",
    }
    local graphql_plain_body = "{ user { id } }" -- No explicit 'query' keyword
    mock_kong.request.get_raw_body = function() return graphql_plain_body end
    
    local instance = GraphQLHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit when operation type is not detected but allowed_operation_types is configured")
    assert(mock_kong.log.warn_called, "Warning should be logged for undetected operation type")
end

-- --- Scenario 8: Invalid regex in block_patterns. ---
do
    reset_mock_kong()
    local conf = {
        block_patterns = { "[" }, -- Malformed regex
        block_status = 400, block_body = "Blocked",
    }
    local graphql_plain_body = "query { user { id } }"
    mock_kong.request.get_raw_body = function() return graphql_plain_body end
    
    local instance = GraphQLHandler:new()
    run_test_and_catch_exit(function() instance:access(conf) end)

    assert(mock_kong.response.exit_called, "Should exit with 500 on invalid regex pattern")
    assert(mock_kong.response.exit_args.status == 500, "Status should be 500 for internal error")
    assert(mock_kong.log.err_called, "Error should be logged for regex compilation failure")
    assert(string.find(mock_kong.log.err_args[1], "Error applying block pattern"), "Error message should indicate regex error")
end

print("All graphql extended tests passed!")
