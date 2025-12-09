# Pongo Test File for the 'assert-condition' plugin

=== TEST 1: Condition is true, request should proceed
--- config
location / {
    access_by_lua_block {
        -- mock upstream response
        kong.response.exit(200, "OK")
    }
}
--- pongo_config
plugins:
  - name: assert-condition
    config:
      condition: "kong.request.get_header('X-Test-Header') == 'allow'"
      on_false_action: "abort"
--- request
GET /
Host: pongo.test
X-Test-Header: allow
--- response_body
OK
--- error_code: 200

=== TEST 2: Condition is false, request should be aborted
--- config
location / {
    access_by_lua_block {
        -- This should not be reached
        kong.response.exit(200, "OK")
    }
}
--- pongo_config
plugins:
  - name: assert-condition
    config:
      condition: "kong.request.get_header('X-Test-Header') == 'allow'"
      on_false_action: "abort"
      abort_status: 403
      abort_message: "Access Denied by Condition"
--- request
GET /
Host: pongo.test
X-Test-Header: deny
--- response_body
{"message":"Access Denied by Condition"}
--- error_code: 403

=== TEST 3: Malformed condition, should trigger error handling
--- pongo_config
plugins:
  - name: assert-condition
    config:
      condition: "kong.request.get_header('X-Test-Header') ==" -- Syntax error
      on_false_action: "abort"
--- request
GET /
--- response_body_like
Error evaluating condition: .*unexpected symbol near '='.*
--- error_code: 500