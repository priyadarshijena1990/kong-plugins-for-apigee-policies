-- apigee-policies-based-plugins/key-value-map-operations/migrations/000_base_kvm_data.lua

-- This migration is for PostgreSQL.
local migration = {
  up = [[
    CREATE TABLE IF NOT EXISTS kvm_data (
      id UUID PRIMARY KEY,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      kvm_name TEXT NOT NULL,
      key TEXT NOT NULL,
      value TEXT,
      expires_at TIMESTAMP WITH TIME ZONE,
      UNIQUE (kvm_name, key)
    );
  ]],
  teardown = function(connector)
    local _, err = connector:query([[
      DROP TABLE IF EXISTS kvm_data;
    ]])
    if err then
      return nil, err
    end
  end,
}

return migration
