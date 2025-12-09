# Pongo Test File for the 'raise-fault' plugin

=== TEST 1: Raise a basic 401 fault
--- config
location / {
    access_by_lua_block {
        -- This should not be reached
        kong.response.exit(200, "OK")
    }
}
--- pongo_config
plugins:
  - name: raise-fault
    config:
      status_code: 401
      fault_body: '{"error":"Unauthorized"}'
      content_type: "application/json"
--- request
GET /
Host: pongo.test
--- response_body
{"error":"Unauthorized"}
--- error_code: 401
--- response_headers
Content-Type: application/json

=== TEST 2: Raise a 503 fault with custom headers
--- pongo_config
plugins:
  - name: raise-fault
    config:
      status_code: 503
      fault_body: "Service Unavailable"
      content_type: "text/plain"
      headers:
        X-Error-Code: "SVC-DOWN"
        "Retry-After": "300"
--- request
GET /
Host: pongo.test
--- response_body
Service Unavailable
--- error_code: 503
--- response_headers
Content-Type: text/plain
X-Error-Code: SVC-DOWN
Retry-After: 300