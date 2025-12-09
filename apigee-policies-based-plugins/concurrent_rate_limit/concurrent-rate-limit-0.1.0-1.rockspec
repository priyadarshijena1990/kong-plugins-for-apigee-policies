package = "concurrent-rate-limit"
version = "0.1.0-1"
source = {
   url = "git://github.com/Kong/kong-plugin-example.git" -- Placeholder, as we don't have a specific repo
}
description = {
   summary = "A brief summary of the concurrent-rate-limit plugin.",
   homepage = "http://konghq.com", -- Placeholder
   license = "Apache 2.0" -- Placeholder
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.concurrent-rate-limit.handler"] = "handler.lua",
      ["kong.plugins.concurrent-rate-limit.schema"] = "schema.lua",
      ["kong.plugins.concurrent-rate-limit.daos"] = "daos.lua",
   }
}