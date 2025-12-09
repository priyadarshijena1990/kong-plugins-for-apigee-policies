local schema = {
  name = "kvm_data",
  primary_key = { "id" },
  fields = {
    { id = { type = "id", required = true, auto = true } },
    { kvm_name = { type = "string", required = true } },
    { key = { type = "string", required = true } },
    { value = { type = "string", required = true } },
    {
      created_at = {
        type = "timestamp",
        required = true,
        auto = true,
        immutable = true
      },
    },
    { expires_at = { type = "timestamp" } },
  },
  entity_checks = {
    {
      unique = { "kvm_name", "key" },
      name = "kvm_data_kvm_name_key_unique"
    }
  }
}

return schema