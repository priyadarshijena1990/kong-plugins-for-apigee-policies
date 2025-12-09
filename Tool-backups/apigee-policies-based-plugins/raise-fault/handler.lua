local kong_meta = require "kong.meta"

local RaiseFaultHandler = {}

RaiseFaultHandler.PRIORITY = 5000 -- High priority to ensure it can interrupt flow
RaiseFaultHandler.VERSION = kong_meta.version

function RaiseFaultHandler:access(conf)
  local headers = conf.headers or {}

  -- Set Content-Type header, allowing override from the headers map
  if not headers["Content-Type"] and not headers["content-type"] then
    headers["Content-Type"] = conf.content_type
  end

  -- The kong.response.exit function handles setting the status, body, and headers.
  -- It's the standard way to terminate a request from a plugin.
  return kong.response.exit(conf.status_code, conf.fault_body or "", headers)
end

-- This plugin's entire purpose is to terminate the request flow,
-- so it only needs to implement the 'access' phase. It will not
-- run in response phases like `header_filter` or `body_filter`
-- because `kong.response.exit` short-circuits the proxying lifecycle.

return RaiseFaultHandler