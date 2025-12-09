-- Rockspec for the json-threat-protection plugin
package = "apigee-json-threat-protection"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}

description = {
  summary = "A Kong plugin to protect against JSON-based threats, mimicking Apigee's JSONThreatProtection policy.",
  license = "Apache 2.0" -- Assuming Apache 2.0, change if needed
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.json-threat-protection.handler"] = "handler.lua",
    ["kong.plugins.json-threat-protection.schema"] = "schema.lua",
  }
}
