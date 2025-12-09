package = "revoke-oauth-v2"
version = "0.1.0-1"
source = {
   url = "git://github.com/Kong/kong-plugin-example.git" -- Placeholder, as we don't have a specific repo
}
description = {
   summary = "A brief summary of the revoke-oauth-v2 plugin.",
   homepage = "http://konghq.com", -- Placeholder
   license = "Apache 2.0" -- Placeholder
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.revoke-oauth-v2.handler"] = "handler.lua",
      ["kong.plugins.revoke-oauth-v2.schema"] = "schema.lua",
   }
}