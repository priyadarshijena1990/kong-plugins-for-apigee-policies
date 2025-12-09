# StatisticsCollector Kong Plugin

## Purpose

The `StatisticsCollector` plugin for Kong Gateway allows you to collect custom data points (metrics) from your API proxy flow and send them to an external statistics collection service. This mirrors the functionality of Apigee's `StatisticsCollector` policy, providing a flexible way to gather business-specific metrics, API usage analytics, or custom operational data.

This plugin operates in the `log` phase, ensuring that the collection process does not block the main request-response cycle, thus not impacting API latency for the client.

## Abilities and Features

*   **Custom Metric Collection**: Define a list of `statistics_to_collect`, where each statistic has a `name` and its `value` is extracted from various sources:
    *   **`header`**: A specific request header.
    *   **`query`**: A specific query parameter.
    *   **`path`**: The full request URI.
    *   **`body`**: A field within a JSON request body.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
    *   **`literal`**: A directly configured static string.
*   **External Service Integration**: Sends collected statistics as a JSON payload via an HTTP request to a configurable `collection_service_url`.
*   **Configurable HTTP Request**: Supports configurable HTTP `method`, `headers`, and `timeout` for the call to the collection service.
*   **Non-Blocking Execution**: Operates in the `log` phase, meaning statistics collection happens asynchronously relative to the client's request, ensuring minimal impact on API response times.
*   **Type Hinting**: Allows specifying an optional `value_type` (string, number, boolean) for statistics, which the plugin attempts to convert before sending, providing clearer data to the external service.

<h2>Important Note</h2>

This plugin acts as a client to an *external* statistics collection service. You are responsible for deploying and managing this service. Since it operates in the `log` phase, any failures during statistics transmission will be logged internally but will *not* affect the client's response. The `on_error_continue` setting essentially controls whether logging an error for this non-critical path should still attempt to "exit" the log phase, which is generally not what you want. It's recommended to leave `on_error_continue` as true or rely on the default behavior.

<h2>Use Cases</h2>

*   **Custom Business Metrics**: Collect unique business metrics like `customer_tier`, `transaction_value`, `product_id`, or `api_version` to track business performance.
*   **API Usage Analytics**: Gain deeper insights into how your APIs are being used by different developers, applications, or geographies.
*   **Operational Monitoring**: Monitor custom operational aspects of your APIs, such as `backend_response_time_category` or `error_type`.
*   **Auditing and Compliance**: Capture detailed auditable events or compliance-related data points.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`collection_service_url`**: (string, required) The full URL of the external service endpoint where collected statistics will be sent.
*   **`method`**: (string, default: `POST`, enum: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`) The HTTP method to use for the call to the statistics collection service.
*   **`headers`**: (map, optional) A dictionary of custom headers to send with the request to the statistics collection service.
*   **`statistics_to_collect`**: (array of records, required) A list of data points (statistics) to extract and send. Each record has:
    *   **`name`**: (string, required) The name of the statistic or metric to collect (e.g., `developer_email`, `transaction_amount`).
    *   **`source_type`**: (string, required, enum: `header`, `query`, `path`, `body`, `shared_context`, `literal`) Specifies where to get the value for this statistic from.
    *   **`source_name`**: (string, required) The name of the header/query parameter, the JSON path for a `body` source (e.g., `$.order.total`), the key in `kong.ctx.shared`, or the literal value itself if `source_type` is `literal`. For `path` source_type, this field is not used as `kong.request.get_uri()` is used.
    *   **`value_type`**: (string, optional, enum: `string`, `number`, `boolean`) A type hint for the external collection service. The plugin attempts to convert the extracted value to this type.

*   **`on_error_continue`**: (boolean, default: `true`) If `true`, request processing (specifically, the `log` phase) will continue even if sending statistics fails. If `false`, this setting primarily impacts internal logging of errors for this non-critical operation. It's recommended to leave `on_error_continue` as true or rely on the default behavior.
*   **`timeout`**: (number, default: `5000`, between: `100` and `60000`) The timeout in milliseconds for the HTTP call to the statistics collection service.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to collect transaction details and user info:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=statistics-collector" \
    --data "config.collection_service_url=http://analytics-collector.example.com/metrics" \
    --data "config.method=POST" \
    --data "config.headers.Content-Type=application/json" \
    --data "config.statistics_to_collect.1.name=developer_id" \
    --data "config.statistics_to_collect.1.source_type=shared_context" \
    --data "config.statistics_to_collect.1.source_name=authenticated_dev_id" \
    --data "config.statistics_to_collect.1.value_type=string" \
    --data "config.statistics_to_collect.2.name=transaction_amount" \
    --data "config.statistics_to_collect.2.source_type=body" \
    --data "config.statistics_to_collect.2.source_name=$.order.total" \
    --data "config.statistics_to_collect.2.value_type=number" \
    --data "config.statistics_to_collect.3.name=api_path" \
    --data "config.statistics_to_collect.3.source_type=path" \
    --data "config.statistics_to_collect.3.source_name=." \
    --data "config.timeout=2000"
```

**Enable globally to collect custom event counts:**

```bash
curl -X POST http://localhost:8001/plugins \
    --data "name=statistics-collector" \
    --data "config.collection_service_url=http://event-logger.example.com/log" \
    --data "config.method=POST" \
    --data "config.statistics_to_collect.1.name=event_name" \
    --data "config.statistics_to_collect.1.source_type=literal" \
    --data "config.statistics_to_collect.1.source_name=api_request_processed" \
    --data "config.statistics_to_collect.2.name=request_id" \
    --data "config.statistics_to_collect.2.source_type=header" \
    --data "config.statistics_to_collect.2.source_name=X-Request-ID"
```