# PublishMessage Kong Plugin

## Purpose

The `PublishMessage` plugin for Kong Gateway allows you to publish messages to a Google Cloud Pub/Sub topic during the API flow. This mirrors the functionality of Apigee's `PublishMessage` policy, enabling your API proxies to participate in event-driven architectures, decouple processes, or send data for logging and analytics.

This plugin operates in the `log` phase, ensuring that publishing messages does not block the main request-response cycle.

## Abilities and Features

*   **Google Cloud Pub/Sub Integration**: Publishes messages to a configurable Pub/Sub topic within a specified Google Cloud project.
*   **Authenticated API Calls**: Authenticates with the Google Cloud Pub/Sub API using an access token, which must be provided by a prior mechanism.
*   **Flexible Message Payload Source**: Retrieves the message payload content from various sources:
    *   **`header`**: A specific request header.
    *   **`query`**: A specific query parameter.
    *   **`body`**: A field within a JSON request body.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
    *   **`literal`**: A directly configured string.
*   **Message Attributes**: Supports attaching custom key-value `message_attributes` to the Pub/Sub message.
*   **Asynchronous Execution**: Operates in the `log` phase, meaning message publishing occurs after the response has been sent to the client, ensuring the main request flow is not impacted by publishing latency.
*   **Error Reporting (Logging Only)**: Failures during message publishing are logged internally but do not directly affect the client's response, as it occurs in the `log` phase.

<h2>Important Note</h2>

This plugin requires a valid Google Cloud access token to authenticate calls to the Pub/Sub API. This token must be made available in `kong.ctx.shared`, a header, query parameter, or literal string by a *prior mechanism* (e.g., a custom authentication plugin, a `ServiceCallout` to an OAuth endpoint to obtain a token, or manual configuration). This plugin does not handle the generation or refreshing of GCP access tokens itself.

<h2>Use Cases</h2>

*   **Event-Driven Architectures**: Emit events (e.g., `order_created`, `user_registered`) from your API proxies to trigger downstream microservices or serverless functions asynchronously.
*   **Asynchronous Processing**: Decouple long-running backend operations from immediate API responses by publishing a message that a separate worker can process.
*   **Logging and Analytics**: Send API-related events, audit logs, or custom metrics to Pub/Sub for centralized collection, streaming, and analysis.
*   **Notifications and Alerts**: Trigger notifications, alerts, or external webhook calls based on specific API activity.
*   **Data Ingestion**: Use APIs as a front-end for data ingestion pipelines that feed into Pub/Sub.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`gcp_project_id`**: (string, required) The Google Cloud Project ID where the Pub/Sub topic resides.
*   **`pubsub_topic_name`**: (string, required) The name of the Google Cloud Pub/Sub topic to publish the message to.
*   **`gcp_access_token_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`, `literal`) Specifies where to get the Google Cloud access token for authenticating the Pub/Sub API call.
*   **`gcp_access_token_source_name`**: (string, required) The name of the header/query parameter, the JSON path for a `body` source, the key in `kong.ctx.shared`, or the literal access token string itself if `gcp_access_token_source_type` is `literal`.
*   **`message_payload_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`, `literal`) Specifies where to get the message content (payload) that will be published to Pub/Sub.
*   **`message_payload_source_name`**: (string, required) The name of the header/query parameter, the JSON path for a `body` source, the key in `kong.ctx.shared`, or the literal message payload string itself if `message_payload_source_type` is `literal`.
*   **`message_attributes`**: (map, optional) A map of key-value pairs to attach as attributes to the Pub/Sub message. Values should be strings.
*   **`on_error_status`**: (number, default: `500`, between: `400` and `599`) (Note: Only for logging phase. Client response already sent).
*   **`on_error_body`**: (string, default: "Message publishing failed.") (Note: Only for logging phase. Client response already sent).
*   **`on_error_continue`**: (boolean, default: `false`) (Note: Always true in log phase as client response is already sent).

<h3>Example Configuration (via Admin API)</h3>

**Enable globally to publish an event based on request body, using a token from shared context:**

```bash
curl -X POST http://localhost:8001/plugins \
    --data "name=publish-message" \
    --data "config.gcp_project_id=my-gcp-project" \
    --data "config.pubsub_topic_name=api-events-topic" \
    --data "config.gcp_access_token_source_type=shared_context" \
    --data "config.gcp_access_token_source_name=gcp_auth_token" \
    --data "config.message_payload_source_type=body" \
    --data "config.message_payload_source_name=." \
    --data "config.message_attributes.event_type=api_call" \
    --data "config.message_attributes.source=api_gateway"
```

**Enable on a Service to publish a simple notification, with a token from a header:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=publish-message" \
    --data "config.gcp_project_id=another-gcp-project" \
    --data "config.pubsub_topic_name=notifications" \
    --data "config.gcp_access_token_source_type=header" \
    --data "config.gcp_access_token_source_name=X-GCP-Token" \
    --data "config.message_payload_source_type=literal" \
    --data "config.message_payload_source_name=API call received." \
    --data "config.message_attributes.priority=low"
```