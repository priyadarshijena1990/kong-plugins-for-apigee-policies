package = "xml-to-json"
version = "0.1.0-1"
source = {
   url = "git://github.com/Kong/kong-plugin-example.git" -- Placeholder, as we don't have a specific repo
}
description = {
   summary = "A brief summary of the xml-to-json plugin.",
   homepage = "http://konghq.com", -- Placeholder
   license = "Apache 2.0" -- Placeholder
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.xml-to-json.handler"] = "handler.lua",
      ["kong.plugins.xml-to-json.schema"] = "schema.lua",
   }
}