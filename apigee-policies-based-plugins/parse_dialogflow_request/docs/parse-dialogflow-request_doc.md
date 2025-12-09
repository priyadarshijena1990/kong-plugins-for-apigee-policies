# ParseDialogflowRequest Kong Plugin

## Purpose

The `ParseDialogflowRequest` plugin for Kong Gateway is designed to process incoming webhook requests from Google Dialogflow. It parses the JSON payload of these requests, extracts key pieces of information (such as detected intent, entities, and query text) using configurable JSONPath expressions, and then stores these extracted values in `kong.ctx.shared`. This makes Dialogflow-related data readily available for subsequent plugins, custom logic, or routing decisions within your API gateway flow.

This plugin provides a structured way to integrate Dialogflow webhooks and leverage its conversational AI capabilities within Kong.

## Abilities and Features

*   **Flexible Request Source**: Retrieves the raw Dialogflow request JSON from:
    *   **`request_body`**: The raw body of the client's incoming request.
    *   **`shared_context`**: A specified key within `kong.ctx.shared` where a previous plugin might have stored the Dialogflow request JSON.
*   **JSON Parsing**: Decodes the Dialogflow request JSON payload into a Lua table for easy manipulation.
*   **JSONPath-based Extraction**: Extracts specific values from the parsed Dialogflow request using configurable dot-notation JSONPaths (e.g., `queryResult.intent.displayName`, `queryResult.parameters.city`).
*   **Shared Context Storage**: Stores all extracted values in designated `output_key`s within `kong.ctx.shared`, making them accessible to other plugins in the `access` phase and beyond.
*   **Robust Error Handling**: Configurable behavior if the Dialogflow request cannot be parsed (e.g., non-JSON body, malformed JSON), allowing either to `on_parse_error_continue` processing or to terminate the request with a custom error response.

<h2>Use Cases</h2>

*   **Dialogflow Webhook Integration**: Act as the primary handler for incoming Dialogflow webhook requests, making the critical conversational data easily consumable.
*   **Intent-based Routing**: Use the extracted intent (e.g., `buy_product`, `check_status`) to dynamically route the request to different upstream services tailored to handle that specific intent.
*   **Entity-driven Logic**: Utilize extracted entities (e.g., `product_name`, `order_id`) to enrich requests, perform database lookups, or trigger specific business logic.
*   **Session Management**: Extract session IDs to maintain conversational context across multiple API calls.
*   **Logging and Analytics**: Capture essential Dialogflow data points for logging, monitoring, and analyzing user interactions with your chatbot.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`source_type`**: (string, required, enum: `request_body`, `shared_context`, default: `request_body`) Specifies where the raw Dialogflow request JSON should be read from.
*   **`source_key`**: (string, conditional) Required if `source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the Dialogflow request JSON (as a string or Lua table).
*   **`mappings`**: (array of records, required) A list of mappings defining how to extract values from the Dialogflow request and store them in `kong.ctx.shared`. Each record has:
    *   **`output_key`**: (string, required) The key in `kong.ctx.shared` where the extracted value will be stored (e.g., `dialogflow_intent`, `dialogflow_city`).
    *   **`dialogflow_jsonpath`**: (string, required) A dot-notation JSONPath expression to specify the value to extract from the parsed Dialogflow request (e.g., `queryResult.intent.displayName`, `queryResult.parameters.fields.city.stringValue`).
*   **`on_parse_error_status`**: (number, default: `400`, between: `400` and `599`) The HTTP status code to return to the client if the Dialogflow request body is not valid JSON or cannot be processed, and `on_parse_error_continue` is `false`.</p>
*   **`on_parse_error_body`**: (string, default: "Invalid Dialogflow request format.") The response body to return to the client if parsing fails and `on_parse_error_continue` is `false`.
*   **`on_parse_error_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if parsing the Dialogflow request fails. If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Route to parse incoming Dialogflow webhook requests:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=parse-dialogflow-request" \
    --data "config.source_type=request_body" \
    --data "config.mappings.1.output_key=dialogflow_intent" \
    --data "config.mappings.1.dialogflow_jsonpath=queryResult.intent.displayName" \
    --data "config.mappings.2.output_key=dialogflow_query_text" \
    --data "config.mappings.2.dialogflow_jsonpath=queryResult.queryText" \
    --data "config.mappings.3.output_key=dialogflow_session_id" \
    --data "config.mappings.3.dialogflow_jsonpath=session" \
    --data "config.on_parse_error_continue=false"
```

**Enable on a Service to parse a Dialogflow request stored in shared context by another plugin:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=parse-dialogflow-request" \
    --data "config.source_type=shared_context" \
    --data "config.source_key=raw_dialogflow_json" \
    --data "config.mappings.1.output_key=dialogflow_action" \
    --data "config.mappings.1.dialogflow_jsonpath=queryResult.action" \
    --data "config.mappings.2.output_key=dialogflow_city_entity" \
    --data "config.mappings.2.dialogflow_jsonpath=queryResult.parameters.fields.city.stringValue"
```

<h2>Accessing Extracted Information</h2>

Extracted information is available in `kong.ctx.shared` using the `output_key`s defined in the mappings.

**Example (in a custom Lua plugin or `lua_condition`):**

```lua
local intent = kong.ctx.shared.dialogflow_intent
local query_text = kong.ctx.shared.dialogflow_query_text

if intent == "book_flight" then
    kong.log.notice("User wants to book a flight with query: ", query_text)
    -- Perform routing or call an external service
end
```
