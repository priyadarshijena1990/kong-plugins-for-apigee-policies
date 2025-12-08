-- Rockspec for the key-value-map-operations plugin
package = "apigee-key-value-map-operations"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}

description = {
  summary = "A Kong plugin to perform CRUD operations on a Key-Value Map, mimicking Apigee's KeyValueMapOperations policy.",
  license = "Apache 2.0" -- Assuming Apache 2.0, change if needed
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.key-value-map-operations.handler"] = "handler.lua",
    ["kong.plugins.key-value-map-operations.schema"] = "schema.lua",
    ["kong.plugins.key-value-map-operations.daos"] = "daos.lua",
  }
}
