return {
  crl_counters = {
    -- The name of the table in the database
    name = "crl_counters",
    -- The primary key of the table
    primary_key = "id",
    -- The fields of the table
    fields = {
      { id = { type = "id", }, },
      { created_at = { type = "timestamp", default = "current_timestamp" }, },
      {
        key = {
          type = "string",
          unique = true, -- Each counter key must be unique
          required = true,
        },
      },
      {
        value = {
          type = "number",
          required = true,
          default = 0,
        },
      },
    },
  },
}
