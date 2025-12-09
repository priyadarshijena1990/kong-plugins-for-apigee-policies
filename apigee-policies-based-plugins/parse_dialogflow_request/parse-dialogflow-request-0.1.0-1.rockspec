package = "parse-dialogflow-request"
version = "0.1.0-1"
source = {
   url = "git://github.com/Kong/kong-plugin-example.git" -- Placeholder, as we don't have a specific repo
}
description = {
   summary = "A brief summary of the parse-dialogflow-request plugin.",
   homepage = "http://konghq.com", -- Placeholder
   license = "Apache 2.0" -- Placeholder
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.parse-dialogflow-request.handler"] = "handler.lua",
      ["kong.plugins.parse-dialogflow-request.schema"] = "schema.lua",
   }
}