return {
  kvm_data = {
    name = "kvm_data",
    primary_key = "id",
    fields = {
      { id = { type = "id", }, },
      { created_at = { type = "timestamp", default = "current_timestamp" }, },
      {
        kvm_name = {
          type = "string",
          required = true,
        },
      },
      {
        key = {
          type = "string",
          required = true,
        },
      },
      {
        value = {
          type = "string",
        },
      },
      {
        expires_at = {
          type = "timestamp",
        },
      },
    },
    indexes = {
      { fields = { "kvm_name", "key" }, unique = true },
    },
  },
}
