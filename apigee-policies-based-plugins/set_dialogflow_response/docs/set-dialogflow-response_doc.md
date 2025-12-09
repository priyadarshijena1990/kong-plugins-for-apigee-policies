# SetDialogflowResponse Kong Plugin

## Purpose

The `SetDialogflowResponse` plugin for Kong Gateway facilitates the processing and transformation of responses originating from a Google Dialogflow agent. While Apigee's "SetDialogflowResponse" is a conceptual operation implemented with multiple policies, this Kong plugin provides a consolidated way to achieve similar functionality. It allows you to extract specific data points from a Dialogflow response (obtained either from the upstream service's response body or from Kong's shared context) and use them to construct a customized, client-facing JSON response.

This plugin is ideal for simplifying Dialogflow's verbose output into a more streamlined and application-specific format.

## Abilities and Features

*   **Flexible Response Source**: Configure the plugin to retrieve the raw Dialogflow response from:
    *   **`upstream_body`**: The body of the response received from the upstream service.
    *   **`shared_context`**: A specified key within `kong.ctx.shared` where a previous plugin or process might have stored the Dialogflow response.
*   **JSONPath-based Mapping**: Define mappings to extract specific values from the Dialogflow JSON response using a simplified dot-notation JSONPath (e.g., `queryResult.fulfillmentText`).
*   **Custom Client Response Construction**: Build a new JSON response body for the client, incorporating the extracted Dialogflow data into defined `output_field`s.
*   **Default Response Handling**: Provide a `default_response_body` (as a JSON string) to be used if the Dialogflow response is invalid, unparsable, or no data is successfully mapped.
*   **Content-Type Control**: Specify the `output_content_type` for the final client response.

<h2>Use Cases</h2>

*   **Streamlining Chatbot Integrations**: Present a clean, concise response to client applications after interacting with a Dialogflow chatbot, hiding Dialogflow's internal complexities.
*   **Customizing API Responses**: Adapt the Dialogflow fulfillment message and other data into a format that perfectly matches your client application's API contract.
*   **Conditional Response Logic**: (Combined with other plugins) Use extracted Dialogflow intents or entities to trigger different subsequent actions or shape the final response.
*   **Decoupling Dialogflow from Client**: Abstract the Dialogflow response structure from your client applications, allowing for easier updates to your Dialogflow agent without affecting client code.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`response_source`**: (string, required, enum: `upstream_body`, `shared_context`, default: `upstream_body`) Specifies where the raw Dialogflow response JSON should be read from.
*   **`shared_context_key`**: (string, conditional, required if `response_source` is `shared_context`) The key in `kong.ctx.shared` where the Dialogflow response (as a JSON string or Lua table) is stored.
*   **`mappings`**: (array of records, optional) An array defining how to map fields from the Dialogflow response to the final client response. Each record has:
    *   **`output_field`**: (string, required) The name of the field in the final client response JSON.
    *   **`dialogflow_jsonpath`**: (string, required) A dot-notation JSONPath (e.g., `queryResult.fulfillmentText`) to specify the value to extract from the parsed Dialogflow response.
*   **`output_content_type`**: (string, default: `application/json`) The `Content-Type` header to set for the final client response.
*   **`default_response_body`**: (string, optional) A JSON string that will be used as the response body if the Dialogflow response cannot be processed, or no successful mappings occur, and `mappings` are defined.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service, mapping Dialogflow upstream body:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=set-dialogflow-response" \
    --data "config.response_source=upstream_body" \
    --data "config.mappings.1.output_field=message" \
    --data "config.mappings.1.dialogflow_jsonpath=queryResult.fulfillmentText" \
    --data "config.mappings.2.output_field=intent" \
    --data "config.mappings.2.dialogflow_jsonpath=queryResult.intent.displayName" \
    --data "config.output_content_type=application/json" \
    --data 'config.default_response_body={"message":"Sorry, I couldn\'t understand. Please try again."}'
```

**Enable on a Route, mapping from shared context:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=set-dialogflow-response" \
    --data "config.response_source=shared_context" \
    --data "config.shared_context_key=my_dialogflow_result" \
    --data "config.mappings.1.output_field=user_response" \
    --data "config.mappings.1.dialogflow_jsonpath=response.text" \
    --data "config.mappings.2.output_field=session_id" \
    --data "config.mappings.2.dialogflow_jsonpath=sessionInfo.session"
```
