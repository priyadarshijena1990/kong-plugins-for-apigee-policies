# Kong Plugin: Concurrent Rate Limit

This plugin limits the number of concurrent "in-flight" requests. It is a custom implementation designed to mimic the functionality of Apigee's deprecated Concurrent Rate Limit policy.

## How it Works

The plugin tracks the number of ongoing requests and rejects new requests if the current number exceeds the configured limit.

A counter is incremented for each request in the `access` phase and decremented at the end of the request lifecycle in the `log` phase.

## Configuration

The plugin supports two policies for storing counters, configured via the `policy` field:

1.  `local` (default): Uses a high-performance, in-memory dictionary shared across worker processes on a **single Kong node**. This is the fastest option but does not work in a clustered environment.
2.  `cluster`: Uses Kong's primary database (PostgreSQL or Cassandra) to share counters across **all nodes in a Kong cluster**. This provides cluster-wide accuracy but comes with a significant performance overhead due to database read/write operations on each request.

---

## Setup

### `local` policy

For the `local` policy to work, you must declare a shared memory dictionary in the `nginx.conf` file used by Kong. Add the following line to your `nginx.conf` inside the `http` block:

```nginx
# in nginx.conf http block
lua_shared_dict concurrent_limit_counters 10m;
```

The size (`10m`) can be adjusted based on the expected number of unique counter keys.

### `cluster` policy

For the `cluster` policy to work, you must run the database migrations for this plugin *before* using it. This will create the necessary `crl_counters` table in your Kong database.

Run the following command from your Kong node:

```sh
kong migrations up
```

**Note on `cluster` policy performance:** This policy is not recommended for very high-throughput APIs due to the performance cost of database transactions on every request. Additionally, the current implementation has a known race condition under high load and should be used with caution. A future version may include an atomic implementation.

---

## Usage

Once configured, apply the plugin to a Service, Route, or globally with your desired configuration.

### Example Configuration:

```yaml
plugins:
- name: concurrent-rate-limit
  config:
    rate: 100
    policy: cluster # or 'local'
    counter_key_source_type: header
    counter_key_source_name: "x-consumer-id"
    on_limit_exceeded_status: 429
    on_limit_exceeded_body: "Too many concurrent requests for this user."
```

This example limits concurrent requests to 100 per consumer, identified by the `x-consumer-id` header, using the cluster-wide database policy.