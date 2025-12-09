package = "soap-message-validation"
version = "0.1.0-1"
source = {
   url = "git://github.com/Kong/kong-plugin-example.git" -- Placeholder, as we don't have a specific repo
}
description = {
   summary = "A brief summary of the soap-message-validation plugin.",
   homepage = "http://konghq.com", -- Placeholder
   license = "Apache 2.0" -- Placeholder
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.soap-message-validation.handler"] = "handler.lua",
      ["kong.plugins.soap-message-validation.schema"] = "schema.lua",
   }
}