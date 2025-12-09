# Kong Plugin: Key-Value Map Operations

This plugin provides a generic interface for interacting with a Key-Value store, mimicking the functionality of Apigee's `KeyValueMapOperations` policy.

It allows API proxies to store, retrieve, and delete simple key-value pairs at runtime. This is useful for storing configuration, lookup values, or small amounts of metadata that need to be accessed by API policies.

## How it Works

The plugin supports GET, PUT, and DELETE operations on a key-value store. It can be configured to use one of two backends:

1.  **`local` policy**: Uses a Kong shared memory dictionary (`ngx.shared.dict`). This is high-performance but the data is local to a single Kong node and is not persistent across restarts.
2.  **`cluster` policy**: Uses Kong's primary database (e.g., PostgreSQL). This allows the KVM to be shared across all nodes in a cluster and is persistent.

### Operations
*   **`get`**: Retrieves a value based on a key and places it in a configured output location (header, body, context, etc.).
*   **`put`**: Takes a key and a value from configured sources and writes them to the KVM. An optional Time-To-Live (TTL) can be set.
*   **`delete`**: Deletes a key-value pair from the KVM.

## Setup

### For `local` policy
You must declare a shared memory dictionary in the `nginx.conf` file used by Kong. The name of this dictionary must match the `kvm_name` you configure in the plugin.

```nginx
# in nginx.conf http block
lua_shared_dict my_kvm_store 10m;
```

### For `cluster` policy
You must run the database migrations for this plugin before using it. This will create the necessary `kvm_data` table in your Kong database.

```sh
kong migrations up
```

## Configuration

*   **`policy`**: (string, required, default: `local`) The storage backend to use: `local` or `cluster`.
*   **`kvm_name`**: (string, required) The name of the KVM. For `local` policy, this must match a `lua_shared_dict` name. For `cluster` policy, this acts as a namespace.
*   **`operation_type`**: (string, required) The operation to perform: `get`, `put`, or `delete`.
*   **`key_source_type` / `key_source_name`**: (required) Specifies the source for the key of the operation.
*   **`value_source_type` / `value_source_name`**: (required for `put`) Specifies the source for the value to be stored.
*   **`output_destination_type` / `output_destination_name`**: (required for `get`) Specifies where to place the retrieved value.
*   **`ttl`**: (number, optional, for `put`) Time-to-live in seconds for the KVM entry. `0` means no expiry.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, continue processing even if the KVM operation fails.

*(Each `*_source_type` can be one of `header`, `query`, `body`, `shared_context`, or `literal`)*

### Example: Retrieving a Value in `cluster` mode

```yaml
plugins:
- name: key-value-map-operations
  config:
    policy: cluster
    kvm_name: "api-settings"
    operation_type: get
    key_source_type: literal
    key_source_name: "backend-timeout"
    output_destination_type: shared_context
    output_destination_name: "retrieved_backend_timeout"
```