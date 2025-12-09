-- Rockspec for the json-to-xml plugin
package = "apigee-json-to-xml"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}

description = {
  summary = "A Kong plugin to convert JSON payloads to XML, mimicking Apigee's JSONtoXML policy.",
  license = "Apache 2.0" -- Assuming Apache 2.0, change if needed
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.json-to-xml.handler"] = "handler.lua",
    ["kong.plugins.json-to-xml.schema"] = "schema.lua",
  }
}
