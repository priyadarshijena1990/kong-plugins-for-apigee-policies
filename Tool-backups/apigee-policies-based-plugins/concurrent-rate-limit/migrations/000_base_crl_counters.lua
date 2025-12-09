-- apigee-policies-based-plugins/concurrent-rate-limit/migrations/000_base_crl_counters.lua

-- This migration is for PostgreSQL. A different syntax might be needed for Cassandra.
local migration = {
  up = [[
    CREATE TABLE IF NOT EXISTS crl_counters (
      id UUID PRIMARY KEY,
      key TEXT UNIQUE,
      value INTEGER,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM   pg_class c
        JOIN   pg_namespace n ON n.oid = c.relnamespace
        WHERE  c.relname = 'crl_counters_key_idx'
        AND    n.nspname = 'public' -- or your schema name
      ) THEN
        CREATE INDEX crl_counters_key_idx ON crl_counters(key);
      END IF;
    END
    $$;
  ]],
  teardown = function(connector)
    local _, err = connector:query([[
      DROP TABLE IF EXISTS crl_counters;
    ]])
    if err then
      return nil, err
    end
  end,
}

return migration
