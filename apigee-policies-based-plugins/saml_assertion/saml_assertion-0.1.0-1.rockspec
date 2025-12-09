package = "saml-assertion"
version = "0.1.0-1"
source = {
   url = "git://github.com/Kong/kong-plugin-example.git" -- Placeholder, as we don't have a specific repo
}
description = {
    summary = "A brief summary of the saml_assertion plugin.",
   homepage = "http://konghq.com", -- Placeholder
   license = "Apache 2.0" -- Placeholder
}
build = {
   type = "builtin",
   modules = {
         ["kong.plugins.saml_assertion.handler"] = "handler.lua",
         ["kong.plugins.saml_assertion.schema"] = "schema.lua",
   }
}