# JSONToXML Kong Plugin

## Purpose

The `JSONToXML` plugin for Kong Gateway facilitates the transformation of JSON formatted content into XML format. This mirrors the functionality of Apigee's `JSONToXML` policy, enabling your API proxy to mediate between services or clients that communicate using different data formats.

This plugin is useful when you need to send a JSON request to a backend that expects XML, or when an upstream service returns JSON that needs to be presented as XML to a client.

## Abilities and Features

*   **Flexible Content Source**: Retrieve JSON content from:
    *   **`request_body`**: The raw body of the client's incoming request.
    *   **`response_body`**: The raw body of the upstream service's response.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
*   **Basic JSON to XML Conversion**: Converts a JSON payload (parsed into a Lua table) into a well-formed XML string.
    *   JSON objects map to XML elements, with keys becoming element names.
    *   JSON arrays map to repeated XML elements with the parent's element name.
    *   Primitive JSON values (strings, numbers, booleans) become XML element text content.
*   **Configurable Root Element**: Specify the `root_element_name` for the top-level XML element.
*   **Flexible Content Output**: Place the converted XML content into:
    *   **`request_body`**: Modifies the request body sent to the upstream.
    *   **`response_body`**: Modifies the response body sent to the client.
    *   **`shared_context`**: Stores the XML string in a specified key in `kong.ctx.shared`.
*   **Robust Error Handling**: Configurable behavior if JSON parsing or XML conversion fails, allowing either to `on_error_continue` processing or to terminate the request with a custom error response.

<h2>Limitations</h2>

This plugin provides a *basic* JSON to XML conversion. It does not support:
*   Complex JSON-to-XML mapping rules (e.g., mapping JSON properties to XML attributes).
*   Handling of mixed content or specific XML schemas.
*   Advanced XML features like namespaces, processing instructions, or comments.
For complex transformations, consider using an external transformation service or a specialized Lua XML library (if available in your Kong environment).

<h2>Use Cases</h2>

*   **Legacy Backend Integration**: Interact with older backend systems that primarily consume XML payloads, even if your frontend or other services send JSON.
*   **Client Compatibility**: Provide an XML API endpoint for clients that specifically require XML responses.
*   **Data Mediation**: Transform data formats at the gateway level to suit the requirements of different consumers or producers.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`source_type`**: (string, required, enum: `request_body`, `response_body`, `shared_context`) Specifies where to get the JSON content for conversion from.
*   **`source_key`**: (string, conditional) Required if `source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the JSON content (as a string or Lua table).
*   **`output_type`**: (string, required, enum: `request_body`, `response_body`, `shared_context`) Specifies where to put the converted XML content.
*   **`output_key`**: (string, conditional) Required if `output_type` is `shared_context`. This is the key in `kong.ctx.shared` to store the XML content.
*   **`root_element_name`**: (string, default: `"root"`) The name of the top-level XML element that will enclose the converted content.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, request/response processing will continue even if JSON parsing or XML conversion fails. If `false`, the request will be terminated.
*   **`on_error_status`**: (number, default: `500`, between: `400` and `599`) The HTTP status code to return to the client if conversion fails and `on_error_continue` is `false`.
*   **`on_error_body`**: (string, default: `"JSON to XML conversion failed."`) The response body to return to the client if conversion fails and `on_error_continue` is `false`.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to convert JSON request body to XML for the upstream:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=json-to-xml" \
    --data "config.source_type=request_body" \
    --data "config.output_type=request_body" \
    --data "config.root_element_name=RequestData" \
    --data "config.on_error_continue=false"
```

**Enable on a Route to convert upstream's JSON response to XML for the client:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=json-to-xml" \
    --data "config.source_type=response_body" \
    --data "config.output_type=response_body" \
    --data "config.root_element_name=ResponseDetails" \
    --data "config.on_error_status=500" \
    --data 'config.on_error_body=Backend response format error.'
```

**Enable globally to convert JSON from shared context and store XML back in shared context:**

```bash
curl -X POST http://localhost:8001/plugins \
    --data "name=json-to-xml" \
    --data "config.source_type=shared_context" \
    --data "config.source_key=my_json_data" \
    --data "config.output_type=shared_context" \
    --data "config.output_key=my_xml_data" \
    --data "config.root_element_name=MyData" \
    --data "config.on_error_continue=true"
```
