-- Rockspec for the decode-jwt plugin
package = "apigee-decode-jwt"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}

description = {
  summary = "A Kong plugin to decode a JWT and extract its claims without verification, mimicking Apigee's DecodeJWT policy.",
  license = "Apache 2.0" -- Assuming Apache 2.0, change if needed
}

dependencies = {
  "lua >= 5.1",
  "lua-resty-jwt >= 0.2.2" -- Use a recent version
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.decode-jwt.handler"] = "handler.lua",
    ["kong.plugins.decode-jwt.schema"] = "schema.lua",
  }
}
