return {
  name = "mock-downstream",
  fields = {
    { consumer = { type = "foreign" } },
    { route = { type = "foreign" } },
    { service = { type = "foreign" } },
    {
      config = {
        type = "record",
        fields = {},
      },
    },
  },
}
