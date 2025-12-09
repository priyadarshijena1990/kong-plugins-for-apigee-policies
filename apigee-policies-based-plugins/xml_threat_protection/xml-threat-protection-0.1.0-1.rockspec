package = "xml-threat-protection"
version = "0.1.0-1"
source = {
   url = "git://github.com/Kong/kong-plugin-example.git" -- Placeholder, as we don't have a specific repo
}
description = {
   summary = "A brief summary of the xml-threat-protection plugin.",
   homepage = "http://konghq.com", -- Placeholder
   license = "Apache 2.0" -- Placeholder
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.xml-threat-protection.handler"] = "handler.lua",
      ["kong.plugins.xml-threat-protection.schema"] = "schema.lua",
   }
}