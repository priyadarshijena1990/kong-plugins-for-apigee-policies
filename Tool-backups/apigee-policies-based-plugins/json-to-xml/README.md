# JSON to XML Plugin (json-to-xml)

The JSON to XML plugin transforms a JSON payload into an XML payload. It is designed to replicate the functionality of Apigee's JSON to XML policy.

The plugin can source the JSON from the request body, response body, or a context variable. It can then replace the original body with the transformed XML content or store the XML in a context variable for other plugins to use.

## How it Works

The plugin uses an external Lua library to perform the JSON to XML conversion. When the plugin is configured, you must specify:
1.  The source of the JSON payload.
2.  The destination for the transformed XML output.
3.  An optional root element name for the resulting XML document.

The plugin can be attached to the request flow (using the `access` phase) or the response flow (using the `body_filter` phase).

## Configuration

The plugin can be configured with the following parameters:

| Parameter                 | Required | Description                                                                                                             |
| ------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------- |
| `json_source`             | **Yes**  | Specifies the source of the JSON. Can be `request_body`, `response_body`, or `shared_context`.                          |
| `json_source_name`        | No       | Required if `json_source` is `shared_context`. The key in `kong.ctx.shared` where the JSON string/table is stored.      |
| `output_destination`      | **Yes**  | Specifies where to place the transformed XML. Can be `replace_request_body`, `replace_response_body`, or `shared_context`. |
| `output_destination_name` | No       | Required if `output_destination` is `shared_context`. The key in `kong.ctx.shared` for storing the XML output.        |
| `root_element_name`       | No       | The name of the root element for the generated XML document. Defaults to `root`.                                        |
| `content_type`            | No       | The `Content-Type` header to set when the body is replaced. Defaults to `application/xml`.                               |
| `on_error_continue`       | No       | If `true`, continues processing even if the transformation fails. Defaults to `false`.                                  |
| `on_error_status`         | No       | The HTTP status to return on failure if `on_error_continue` is `false`. Defaults to `500`.                              |
| `on_error_body`           | No       | The response body to return on failure if `on_error_continue` is `false`. Defaults to `JSON to XML conversion failed.`. |

## Usage Example

### Scenario

An upstream service returns a JSON response, but the client expects XML. We want to convert the response body before it is sent back to the client.

### Plugin Configuration

```yaml
plugins:
  - name: json-to-xml
    config:
      json_source: "response_body"
      output_destination: "replace_response_body"
      root_element_name: "customer_data"
      content_type: "application/xml; charset=utf-8"
```

### Upstream Response (JSON)

The upstream service sends this response to Kong:
```json
{
  "id": "12345",
  "name": "John Doe",
  "orders": [
    { "order_id": "A567", "amount": 99.95 },
    { "order_id": "B890", "amount": 25.50 }
  ]
}
```

### Final Client Response (XML)

The `json-to-xml` plugin intercepts the response and transforms it. The client receives:
```xml
<customer_data>
  <id>12345</id>
  <name>John Doe</name>
  <orders>
    <order_id>A567</order_id>
    <amount>99.95</amount>
  </orders>
  <orders>
    <order_id>B890</order_id>
    <amount>25.50</amount>
  </orders>
</customer_data>
```