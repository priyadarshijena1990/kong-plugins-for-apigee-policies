-- unittests/access-entity/handler_spec.lua

describe("access-entity handler", function()
  lazy_setup(function()
    require("kong.pdk.private.preseed").preseed({
      ctx = {
        shared = {}
      }
    })
  end)

  it("should do nothing if no consumer is present", function()
    -- Mock kong.client.get_consumer to return nil
    patch(kong.client, "get_consumer", function() return nil end)
    
    local handler = require "apigee-policies-based-plugins.access-entity.handler"
    handler:access({ context_variable_name = "consumer_entity" })
    
    assert.is_nil(kong.ctx.shared.consumer_entity)
  end)

  it("should store consumer details in ctx.shared", function()
    local consumer = {
      id = "123",
      username = "testuser",
      custom_id = "abc",
      created_at = 123456,
      tags = {"tag1", "tag2"}
    }
    -- Mock kong.client.get_consumer to return a consumer
    patch(kong.client, "get_consumer", function() return consumer end)
    -- Mock kong.consumer.get_groups to return an empty list
    patch(kong.consumer, "get_groups", function() return {} end)
    
    local handler = require "apigee-policies-based-plugins.access-entity.handler"
    handler:access({ context_variable_name = "consumer_entity" })
    
    assert.is_not_nil(kong.ctx.shared.consumer_entity)
    assert.same(consumer, kong.ctx.shared.consumer_entity)
  end)

  it("should store consumer groups in ctx.shared", function()
    local consumer = {
      id = "123",
      username = "testuser",
    }
    local groups = {
      { name = "group1" },
      { name = "group2" }
    }
    -- Mock kong.client.get_consumer to return a consumer
    patch(kong.client, "get_consumer", function() return consumer end)
    -- Mock kong.consumer.get_groups to return a list of groups
    patch(kong.consumer, "get_groups", function() return groups end)
    
    local handler = require "apigee-policies-based-plugins.access-entity.handler"
    handler:access({ context_variable_name = "consumer_entity" })
    
    assert.is_not_nil(kong.ctx.shared.consumer_entity)
    assert.same({"group1", "group2"}, kong.ctx.shared.consumer_entity.groups)
  end)

  it("should handle errors when fetching consumer groups", function()
    local consumer = {
      id = "123",
      username = "testuser",
    }
    -- Mock kong.client.get_consumer to return a consumer
    patch(kong.client, "get_consumer", function() return consumer end)
    -- Mock kong.consumer.get_groups to return an error
    patch(kong.consumer, "get_groups", function() return nil, "error" end)
    
    local handler = require "apigee-policies-based-plugins.access-entity.handler"
    handler:access({ context_variable_name = "consumer_entity" })
    
    assert.is_not_nil(kong.ctx.shared.consumer_entity)
    assert.same({}, kong.ctx.shared.consumer_entity.groups)
  end)
end)
