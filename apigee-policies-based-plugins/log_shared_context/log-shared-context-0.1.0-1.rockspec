-- Rockspec for the log-shared-context plugin
package = "apigee-log-shared-context"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}

description = {
  summary = "A Kong plugin to log the contents of the shared context, mimicking Apigee's MessageLogging policy.",
  license = "Apache 2.0" -- Assuming Apache 2.0, change if needed
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.log-shared-context.handler"] = "handler.lua",
    ["kong.plugins.log-shared-context.schema"] = "schema.lua",
  }
}
