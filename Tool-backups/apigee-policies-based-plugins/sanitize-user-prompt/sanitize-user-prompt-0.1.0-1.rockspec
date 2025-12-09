package = "sanitize-user-prompt"
version = "0.1.0-1"
source = {
   url = "git://github.com/Kong/kong-plugin-example.git" -- Placeholder, as we don't have a specific repo
}
description = {
   summary = "A brief summary of the sanitize-user-prompt plugin.",
   homepage = "http://konghq.com", -- Placeholder
   license = "Apache 2.0" -- Placeholder
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.sanitize-user-prompt.handler"] = "handler.lua",
      ["kong.plugins.sanitize-user-prompt.schema"] = "schema.lua",
   }
}