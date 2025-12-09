package = "graphql-security-filter"
version = "0.1.0-1"
source = {
   url = "git://github.com/Kong/kong-plugin-example.git" -- Placeholder, as we don't have a specific repo
}
description = {
   summary = "A brief summary of the graphql-security-filter plugin.",
   homepage = "http://konghq.com", -- Placeholder
   license = "Apache 2.0" -- Placeholder
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.graphql-security-filter.handler"] = "handler.lua",
      ["kong.plugins.graphql-security-filter.schema"] = "schema.lua",
   }
}