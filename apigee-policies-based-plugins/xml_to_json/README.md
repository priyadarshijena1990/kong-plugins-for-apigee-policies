# XML to JSON Plugin (xml-to-json)

The XML to JSON plugin transforms an XML payload into a JSON payload. It is designed to replicate the functionality of Apigee's XML to JSON policy.

The plugin can source the XML from the request body, response body, or a context variable. It can then replace the original body with the transformed JSON content or store the JSON in a context variable for other plugins to use.

## How it Works

The plugin uses an external Lua library to parse the XML into a Lua table, which is then encoded into a JSON string. When the plugin is configured, you must specify:
1.  The source of the XML payload.
2.  The destination for the transformed JSON output.

The plugin can be attached to the request flow (using the `access` phase) or the response flow (using the `body_filter` phase).

## Configuration

The plugin can be configured with the following parameters:

| Parameter                 | Required | Description                                                                                                             |
| ------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------- |
| `xml_source`              | **Yes**  | Specifies the source of the XML. Can be `request_body`, `response_body`, or `shared_context`.                           |
| `xml_source_name`         | No       | Required if `xml_source` is `shared_context`. The key in `kong.ctx.shared` where the XML string is stored.               |
| `output_destination`      | **Yes**  | Specifies where to place the transformed JSON. Can be `replace_request_body`, `replace_response_body`, or `shared_context`. |
| `output_destination_name` | No       | Required if `output_destination` is `shared_context`. The key in `kong.ctx.shared` for storing the JSON output.         |
| `content_type`            | No       | The `Content-Type` header to set when the body is replaced. Defaults to `application/json`.                               |
| `on_error_continue`       | No       | If `true`, continues processing even if the transformation fails. Defaults to `false`.                                  |
| `on_error_status`         | No       | The HTTP status to return on failure if `on_error_continue` is `false`. Defaults to `500`.                              |
| `on_error_body`           | No       | The response body to return on failure if `on_error_continue` is `false`. Defaults to `XML to JSON conversion failed.`. |

## Usage Example

### Scenario

A client sends an XML payload, but the upstream service expects JSON. We want to convert the request body before it is proxied.

### Plugin Configuration

```yaml
plugins:
  - name: xml-to-json
    config:
      xml_source: "request_body"
      output_destination: "replace_request_body"
      content_type: "application/json; charset=utf-8"
```

### Incoming Request (XML)

The client sends this request to Kong:
```http
POST /my-service HTTP/1.1
Host: kong-gateway.com
Content-Type: application/xml

<customer>
  <id>12345</id>
  <name>John Doe</name>
</customer>
```

### Resulting Upstream Request (JSON)

The `xml-to-json` plugin intercepts the request and transforms it. The upstream service receives a request with the following JSON body:
```json
{
  "customer": {
    "id": "12345",
    "name": "John Doe"
  }
}
```