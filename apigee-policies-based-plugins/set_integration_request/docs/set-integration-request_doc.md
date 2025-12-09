# SetIntegrationRequest Kong Plugin

## Purpose

The `SetIntegrationRequest` plugin for Kong Gateway is designed to configure and prepare requests for external integration services, specifically mimicking the functionality of Apigee's `SetIntegrationRequest` policy. This plugin collects necessary information (integration name, trigger name, and dynamic parameters) from the incoming client request and makes it available in `kong.ctx.shared` for a subsequent plugin or custom Lua logic to use for invoking the actual integration endpoint.

This plugin does *not* directly call the integration service. Instead, it extracts and formats the required data, allowing for flexible integration patterns within Kong.

## Abilities and Features

*   **Integration and Trigger Configuration**: Allows specifying the `integration_name` and `trigger_name` which identify the target external integration.
*   **Dynamic Parameter Extraction**: Extracts parameter values from various sources within the incoming client request:
    *   **`literal`**: Use a static, predefined value.
    *   **`header`**: Extract value from a specified request header.
    *   **`query`**: Extract value from a specified query parameter.
    *   **`body`**: Extract value from the request body (supports entire body or top-level JSON keys).
*   **Parameter Type Conversion**: Automatically converts extracted parameter values to the specified target type: `STRING`, `INT`, `BOOLEAN`, or `JSON`.
*   **Context Sharing**: All processed integration request details (integration name, trigger name, and parsed parameters) are stored in `kong.ctx.shared.integration_request`, making them accessible to other plugins or custom Lua code later in the request lifecycle.

## Use Cases

*   **Preparing for Apigee Integrations**: Set up the necessary data structure to call Apigee Integrations (formerly Application Integration) from a Kong-managed API.
*   **Decoupling Logic**: Facilitate the offloading of complex business logic from the API gateway to external integration platforms, with Kong handling the API management aspects.
*   **Flexible Data Mapping**: Transform and map incoming client request data into a format suitable for an external integration service.
*   **Pre-processing for External Services**: Prepare requests for any external service that requires specific named parameters derived from the client's request.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`integration_name`**: (string, required) The name of the target external integration service.
*   **`trigger_name`**: (string, required) The name of the specific trigger or operation within the integration to invoke.
*   **`parameters`**: (array of records, optional) A list of parameters to be passed to the integration. Each record has the following fields:
    *   **`name`**: (string, required) The name of the parameter as expected by the integration.
    *   **`type`**: (string, required, enum: `STRING`, `INT`, `BOOLEAN`, `JSON`) The target data type for the parameter value.
    *   **`source`**: (string, required, enum: `header`, `query`, `body`, `literal`) Specifies where to obtain the parameter's value from.
    *   **`source_name`**: (string, optional)
        *   For `source="header"`, this is the name of the request header (e.g., `X-Customer-ID`).
        *   For `source="query"`, this is the name of the query parameter (e.g., `orderId`).
        *   For `source="body"`, if provided, it's assumed to be a top-level key in a JSON request body. If empty or `.`, the entire parsed JSON body is used.
        *   Not used for `source="literal"`.
    *   **`value`**: (string, optional)
        *   The literal string value to use when `source="literal"`. 
        *   Not used for other `source` types.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service with various parameter sources:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=set-integration-request" \
    --data "config.integration_name=MyOrderProcessingIntegration" \
    --data "config.trigger_name=ProcessNewOrder" \
    --data "config.parameters.1.name=orderId" \
    --data "config.parameters.1.type=STRING" \
    --data "config.parameters.1.source=query" \
    --data "config.parameters.1.source_name=order_id" \
    --data "config.parameters.2.name=customerEmail" \
    --data "config.parameters.2.type=STRING" \
    --data "config.parameters.2.source=header" \
    --data "config.parameters.2.source_name=X-Customer-Email" \
    --data "config.parameters.3.name=isExpress" \
    --data "config.parameters.3.type=BOOLEAN" \
    --data "config.parameters.3.source=literal" \
    --data "config.parameters.3.value=true" \
    --data "config.parameters.4.name=orderPayload" \
    --data "config.parameters.4.type=JSON" \
    --data "config.parameters.4.source=body" \
    --data "config.parameters.4.source_name=."
```

<h2>Accessing Information</h2>

Once the `SetIntegrationRequest` plugin has executed (in the `rewrite` phase), the processed integration request information can be accessed in subsequent phases and plugins via `kong.ctx.shared.integration_request`.

**Example (in a custom Lua plugin's `access` or `header_filter` phase):**

```lua
local integration_req = kong.ctx.shared.integration_request

if integration_req then
    kong.log.notice("Integration Name: ", integration_req.integration_name)
    kong.log.notice("Trigger Name: ", integration_req.trigger_name)

    for param_name, param_value in pairs(integration_req.parameters) do
        kong.log.notice("Parameter '", param_name, "': ", tostring(param_value))
    end

    -- You could then use this information to construct an HTTP request
    -- to an external integration endpoint.
    -- For example:
    -- kong.service.request_forward("http://my-integration-endpoint.com/invoke", {
    --     method = "POST",
    --     body = cjson.encode(integration_req)
    -- })
end
```