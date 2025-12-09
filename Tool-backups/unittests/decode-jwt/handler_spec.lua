-- unittests/decode-jwt/handler_spec.lua

describe("decode-jwt handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should get JWT from header and extract claims", function()
    local handler = require "apigee-policies-based-plugins.decode-jwt.handler"
    -- A valid JWT with payload {"sub":"123"}
    local jwt_string = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjMifQ.fl8uQXs-Tii6582Z2ctyVwF3M5j5a7j29Hh_f4p-rU8"
    
    local conf = {
      jwt_source_type = "header",
      jwt_source_name = "x-jwt",
      claims_to_extract = {
        { claim_name = "sub", output_key = "subject" }
      },
      on_error_continue = true
    }
    
    spy.on(kong.request, "get_header", function(name)
      if name == "x-jwt" then return jwt_string end
    end)
    
    handler:access(conf)
    assert.equal("123", kong.ctx.shared.subject)
  end)

  it("should store header and payload", function()
    local handler = require "apigee-policies-based-plugins.decode-jwt.handler"
    -- A valid JWT with payload {"sub":"123"}
    local jwt_string = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjMifQ.fl8uQXs-Tii6582Z2ctyVwF3M5j5a7j29Hh_f4p-rU8"

    local conf = {
      jwt_source_type = "header",
      jwt_source_name = "x-jwt",
      store_header_to_shared_context_key = "jwt_header",
      store_all_claims_in_shared_context_key = "jwt_payload",
      on_error_continue = true
    }
    
    spy.on(kong.request, "get_header", function(name)
      if name == "x-jwt" then return jwt_string end
    end)

    handler:access(conf)

    assert.is_not_nil(kong.ctx.shared.jwt_header)
    assert.same({ alg = "HS256", typ = "JWT" }, kong.ctx.shared.jwt_header)
    assert.is_not_nil(kong.ctx.shared.jwt_payload)
    assert.same({ sub = "123" }, kong.ctx.shared.jwt_payload)
  end)
end)
