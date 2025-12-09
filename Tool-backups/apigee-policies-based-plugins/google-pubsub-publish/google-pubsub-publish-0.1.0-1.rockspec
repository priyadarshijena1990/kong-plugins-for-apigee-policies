package = "google-pubsub-publish"
version = "0.1.0-1"
source = {
   url = "git://github.com/Kong/kong-plugin-example.git" -- Placeholder, as we don't have a specific repo
}
description = {
   summary = "A brief summary of the google-pubsub-publish plugin.",
   homepage = "http://konghq.com", -- Placeholder
   license = "Apache 2.0" -- Placeholder
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.google-pubsub-publish.handler"] = "handler.lua",
      ["kong.plugins.google-pubsub-publish.schema"] = "schema.lua",
   }
}