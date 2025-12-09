-- Rockspec for the access-entity plugin
package = "apigee-access-entity"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}

description = {
  summary = "A Kong plugin to extract attributes from authenticated entities (consumer/credential).",
  license = "Apache 2.0" -- Assuming Apache 2.0, change if needed
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.access-entity.handler"] = "handler.lua",
    ["kong.plugins.access-entity.schema"] = "schema.lua",
  }
}
