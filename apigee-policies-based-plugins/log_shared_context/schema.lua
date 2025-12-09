local typedefs = require "kong.db.schema.typedefs"
return {
  name = "log-shared-context",
  fields = {
    { config = { type = "record", fields = {
      { log_key = { type = "string", required = true, description = "A key to identify this log entry." } },
      { target_key_prefix = { type = "string", default = "", description = "Optional: If set, only shared context keys starting with this prefix will be logged." } },
      { http_endpoint = { type = "string", description = "Optional: If set, the log will be sent to this HTTP endpoint. If omitted, it will be written to Kong's standard log file." } },
      { http_method = { type = "string", default = "POST", enum = { "POST", "PUT", "PATCH" }, description = "The HTTP method to use when sending the log to the endpoint." } },
      { http_headers = { type = "map", default = {}, description = "Optional: Headers to send with the HTTP log request (e.g., for authentication)." } },
    }}},
  },
}
