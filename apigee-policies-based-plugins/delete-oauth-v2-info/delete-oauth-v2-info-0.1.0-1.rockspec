package = "delete-oauth-v2-info"
version = "0.1.0-1"
source = {
   url = "git://github.com/Kong/kong-plugin-example.git" -- Placeholder, as we don't have a specific repo
}
description = {
   summary = "A brief summary of the delete-oauth-v2-info plugin.",
   homepage = "http://konghq.com", -- Placeholder
   license = "Apache 2.0" -- Placeholder
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.delete-oauth-v2-info.handler"] = "handler.lua",
      ["kong.plugins.delete-oauth-v2-info.schema"] = "schema.lua",
   }
}