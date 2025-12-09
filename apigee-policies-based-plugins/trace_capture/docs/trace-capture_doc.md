# TraceCapture Kong Plugin

## Purpose

The `TraceCapture` plugin for Kong Gateway allows you to capture configurable data points from your API flow (request, response, or internal variables) for debugging, custom logging, or integration with external tracing systems. This mimics the conceptual capability of "trace capture" in Apigee, providing granular visibility into your API's runtime behavior.

This plugin helps in understanding request processing, debugging complex interactions, and collecting custom data for analytics or monitoring.

## Abilities and Features

*   **Multi-Phase Data Capture**: Captures data points from various `source_type`s (headers, query params, path, body, response headers, response body, `kong.ctx.shared`, status, latency) across `access`, `body_filter`, and `log` phases, ensuring availability of appropriate data.
*   **Shared Context Storage**: Optionally stores captured data points in `kong.ctx.shared` under a configurable prefix. This makes the data accessible to subsequent plugins or custom Lua logic within the same request lifecycle.
*   **External Logging/Tracing Integration**: Optionally sends all captured trace data as a JSON payload to a configurable `external_logger_url` (e.g., a simple HTTP endpoint that accepts trace events). This call occurs in the `log` phase, making it non-blocking to the main request flow.
*   **Configurable External Logger Call**: Supports configurable HTTP `method`, `headers`, and `timeout` for the call to the external logger.
*   **Robust Error Handling**: `on_error_continue` setting primarily impacts whether errors during data retrieval or external calls are simply logged or, in the `access` phase, could lead to request termination.

<h2>Important Note</h2>

This plugin provides a mechanism for *capturing* data for tracing. It is not a full-fledged distributed tracing solution by itself (e.g., OpenTracing, OpenTelemetry). It provides the building blocks to send specific trace events to an external system that can then correlate and visualize traces.

<h2>Use Cases</h2>

*   **Custom Logging & Auditing**: Collect specific contextual information for custom logs, audit trails, or debugging purposes.
*   **Debugging Complex Flows**: Capture intermediate states, variable values, or policy outcomes at different stages of the API flow to aid in debugging.
*   **Performance Monitoring**: Capture custom latency metrics, resource usage, or specific event timings.
*   **Integration with External Tracing Systems**: Send relevant granular data points to external APM (Application Performance Monitoring) or distributed tracing tools for correlation and visualization.
*   **Security Context Capture**: Capture specific data points related to security decisions, user attributes, or authentication results for security auditing.

## Configuration

The plugin supports the following configuration parameters:

*   **`trace_points`**: (array of records, required) A list defining the data points to capture. Each record has:
    *   **`name`**: (string, required) A unique name for this captured data point (e.g., `user_id`, `request_method`).
    *   **`source_type`**: (string, required, enum: `header`, `query`, `path`, `body`, `shared_context`, `literal`, `response_header`, `response_body`, `status`, `latency`) Specifies where to get the value for this trace point from.
    *   **`source_name`**: (string, required) The name of the header/query parameter, the JSON path for a `body`/`response_body` source, the key in `kong.ctx.shared`, or the literal value itself if `source_type` is `literal`. Not used for `path`, `status`, `latency` (these are directly available).
*   **`store_in_shared_context_prefix`**: (string, optional) If set, all captured data points will be stored in `kong.ctx.shared` with this prefix (e.g., if prefix is `my_trace` and a trace point is named `user_id`, it will be stored as `kong.ctx.shared.my_trace.user_id`).
*   **`external_logger_url`**: (string, optional) The URL of an external service to send the aggregated captured trace data to. This call happens in the `log` phase.
*   **`method`**: (string, default: `POST`, enum: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`) The HTTP method for the call to the external logger, if `external_logger_url` is configured.
*   **`headers`**: (map, optional) A dictionary of custom headers to send with the request to the external logger.
*   **`timeout`**: (number, default: `5000`, between: `100` and `60000`) The timeout in milliseconds for the HTTP call to the external logger.
*   **`on_error_continue`**: (boolean, default: `true`) If `true`, errors during data retrieval or external calls will generally be logged and processing will continue. If `false`, errors in the `access` phase could terminate the request.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to capture various request/response details and log externally:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=trace-capture" \
    --data "config.trace_points.1.name=client_ip" \
    --data "config.trace_points.1.source_type=header" \
    --data "config.trace_points.1.source_name=X-Real-IP" \
    --data "config.trace_points.2.name=request_path" \
    --data "config.trace_points.2.source_type=path" \
    --data "config.trace_points.3.name=request_method" \
    --data "config.trace_points.3.source_type=header" \
    --data "config.trace_points.3.source_name=X-HTTP-Method-Override" \
    --data "config.trace_points.3.default_value=GET" \
    --data "config.trace_points.4.name=response_status" \
    --data "config.trace_points.4.source_type=status" \
    --data "config.trace_points.5.name=upstream_latency" \
    --data "config.trace_points.5.source_type=latency" \
    --data "config.store_in_shared_context_prefix=my_trace_data" \
    --data "config.external_logger_url=http://trace-collector.example.com/api/v1/traces" \
    --data "config.method=POST" \
    --data "config.headers.Content-Type=application/json" \
    --data "config.timeout=3000"
```

**Enable on a Route to capture a custom variable and part of the response body, storing only in shared context:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=trace-capture" \
    --data "config.trace_points.1.name=transaction_id" \
    --data "config.trace_points.1.source_type=shared_context" \
    --data "config.trace_points.1.source_name=tx_id_from_jwt" \
    --data "config.trace_points.2.name=result_code" \
    --data "config.trace_points.2.source_type=response_body" \
    --data "config.trace_points.2.source_name=$.status.code" \
    --data "config.store_in_shared_context_prefix=response_summary"
```