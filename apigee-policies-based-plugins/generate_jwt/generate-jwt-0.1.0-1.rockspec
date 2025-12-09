-- Rockspec for the generate-jwt plugin
package = "apigee-generate-jwt"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}

description = {
  summary = "A Kong plugin to generate a signed JWT, mimicking Apigee's GenerateJWT policy.",
  license = "Apache 2.0" -- Assuming Apache 2.0, change if needed
}

dependencies = {
  "lua >= 5.1",
  "lua-resty-jwt >= 0.2.2" -- Use a recent version
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.generate-jwt.handler"] = "handler.lua",
    ["kong.plugins.generate-jwt.schema"] = "schema.lua",
  }
}
