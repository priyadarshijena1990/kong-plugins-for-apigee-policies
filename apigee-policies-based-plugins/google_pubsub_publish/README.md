# Kong Plugin: Google Pub/Sub Publish

This plugin publishes messages to a Google Cloud Pub/Sub topic. It is designed to mimic the functionality of Apigee's `MessageLogging` policy when configured to send data to Pub/Sub.

This plugin enables your API proxies to participate in event-driven architectures, decouple processes, or send data for logging and analytics.

## How it Works

The plugin can be configured to run in one of two Kong phases:

1.  **`access` phase**:
    *   The publish operation is performed synchronously.
    *   If publishing fails, the plugin can optionally terminate the client's request with a configurable error status and body. This is suitable for critical messages where the API flow should not continue if the message cannot be published.

2.  **`log` phase**:
    *   The publish operation is performed asynchronously ("fire-and-forget").
    *   The plugin initiates the Pub/Sub API call in a background timer, and the client's response is not blocked.
    *   Failures during publishing are logged internally but do not affect the client's response. This is suitable for non-critical messages like analytics or auditing.

The plugin retrieves the message payload and a GCP access token from configurable sources. It constructs the Pub/Sub API request, base64-encodes the payload, and sends it to the Pub/Sub API endpoint.

## Dependencies

This plugin requires a valid Google Cloud access token to authenticate calls to the Pub/Sub API. This token must be made available in `kong.ctx.shared`, a header, query parameter, or literal string by a *prior mechanism* (e.g., a custom authentication plugin, a `ServiceCallout` to an OAuth endpoint to obtain a token, or manual configuration). This plugin does not handle the generation or refreshing of GCP access tokens itself.

## Configuration

*   **`phase`**: (string, required, default: `log`) The Kong phase in which to execute the publish operation: `access` or `log`.
*   **`gcp_project_id`**: (string, required) The Google Cloud Project ID where the Pub/Sub topic resides.
*   **`pubsub_topic_name`**: (string, required) The name of the Google Cloud Pub/Sub topic.
*   **`gcp_access_token_source_type` / `gcp_access_token_source_name`**: (required) Specifies where to get the GCP access token.
*   **`message_payload_source_type` / `message_payload_source_name`**: (required) Specifies where to get the message content (payload).
*   **`message_attributes`**: (map, optional) Key-value pairs to attach as attributes to the Pub/Sub message.
*   **`on_error_status` / `on_error_body` / `on_error_continue`**: (applicable in `access` phase) Configures error handling for blocking operations.

*(Each `*_source_type` can be one of `header`, `query`, `body`, `shared_context`, or `literal`)*

### Example: Asynchronous Publishing (default)

```yaml
plugins:
- name: google-pubsub-publish
  config:
    phase: log # default
    gcp_project_id: "my-gcp-project"
    pubsub_topic_name: "api-events"
    gcp_access_token_source_type: shared_context
    gcp_access_token_source_name: "gcp_auth_token"
    message_payload_source_type: body
    message_payload_source_name: "." # publish the whole request body
```

### Example: Synchronous Publishing with Error Handling

```yaml
plugins:
- name: google-pubsub-publish
  config:
    phase: access
    gcp_project_id: "my-gcp-project"
    pubsub_topic_name: "critical-events"
    gcp_access_token_source_type: literal
    gcp_access_token_source_name: "ya29.a0AR..." # NOT RECOMMENDED TO HARDCODE
    message_payload_source_type: shared_context
    message_payload_source_name: "critical_data"
    on_error_continue: false
    on_error_status: 500
    on_error_body: "Failed to publish critical event."
```
