-- Rockspec for the invalidate-cache plugin
package = "apigee-invalidate-cache"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}

description = {
  summary = "A Kong plugin to invalidate cache entries, mimicking Apigee's InvalidateCache policy.",
  license = "Apache 2.0" -- Assuming Apache 2.0, change if needed
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.invalidate-cache.handler"] = "handler.lua",
    ["kong.plugins.invalidate-cache.schema"] = "schema.lua",
  }
}
