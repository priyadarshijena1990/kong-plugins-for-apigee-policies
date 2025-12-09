-- Rockspec for the verify-jws plugin
package = "apigee-verify-jws"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}

description = {
  summary = "A Kong plugin to verify a JWS and extract claims, mimicking Apigee's VerifyJWS policy.",
  license = "Apache 2.0" -- Assuming Apache 2.0, change if needed
}

dependencies = {
  "lua >= 5.1",
  "lua-resty-jwt >= 0.2.2" -- Use a recent version
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.verify-jws.handler"] = "handler.lua",
    ["kong.plugins.verify-jws.schema"] = "schema.lua",
  }
}
