# Kong Plugin: Log Shared Context

This plugin provides a flexible way to log the contents of Kong's shared request context (`kong.ctx.shared`). It is designed to mimic the functionality of Apigee's `MessageLogging` policy.

This is useful for debugging, auditing, or sending transaction-specific data to an external logging service.

## How it Works

The plugin runs in the `log` phase, which executes at the end of the request lifecycle. It collects all data from `kong.ctx.shared` (or a subset of it, based on a prefix) and then either:
1.  **Logs to a remote HTTP endpoint**: If an endpoint is configured, the plugin makes an asynchronous, "fire-and-forget" HTTP call, sending the collected data as a JSON payload. This does not add latency to the client's request.
2.  **Logs to Kong's log file**: If no HTTP endpoint is configured, it writes the JSON payload to Kong's standard `notice.log` file using `kong.log.notice()`.

## Configuration

*   **`log_key`**: (string, required) A key or message to identify this specific log entry.
*   **`target_key_prefix`**: (string, optional) If set, only keys from `kong.ctx.shared` that start with this prefix will be included in the log. If omitted, the entire shared context is logged.
*   **`http_endpoint`**: (string, optional) If provided, the URL of the remote logging service. If this is omitted, the plugin falls back to logging to the local Kong log file.
*   **`http_method`**: (string, default: `POST`) The HTTP method to use for the remote log call.
*   **`http_headers`**: (map, optional) Custom headers to send with the remote log call (e.g., for authentication).

### Example: Logging to a Remote Splunk/ELK Endpoint

```yaml
plugins:
- name: log-shared-context
  config:
    log_key: "TransactionSummary"
    target_key_prefix: "txn_"
    http_endpoint: "https://my-log-aggregator.com/ingest"
    http_headers:
      Authorization: "Splunk 12345-ABCDE"
```

In this scenario:
1.  At the end of a request, the plugin gathers all keys from `kong.ctx.shared` that start with `txn_` (e.g., `txn_user_id`, `txn_trace_id`).
2.  It constructs a JSON payload like:
    ```json
    {
      "log_key": "TransactionSummary",
      "timestamp": 1678886400.123,
      "data": {
        "txn_user_id": "user-abc",
        "txn_trace_id": "trace-xyz"
      }
    }
    ```
3.  It makes an asynchronous `POST` request with this payload to `https://my-log-aggregator.com/ingest`, including the `Authorization` header.

### Example: Logging to the Local Kong Log for Debugging

```yaml
plugins:
- name: log-shared-context
  config:
    log_key: "DebugContext"
```
This simpler configuration will log the entire content of `kong.ctx.shared` to the `notice.log` file for easy debugging during development.
