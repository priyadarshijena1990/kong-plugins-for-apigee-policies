# XSL Transform Plugin (xsltransform)

The XSL Transform plugin performs an XSLT (Extensible Stylesheet Language Transformations) on an XML payload. It is designed to replicate the functionality of Apigee's XSL Transform policy.

The plugin can source the XML from the request body, response body, or a context variable. It can then replace the body with the transformed content or store it in a context variable for other plugins to use.

## How it Works

The plugin uses an external Lua Saxon library to perform the XSLT 1.0/2.0/3.0 transformations. When the plugin is configured, you must specify:
1.  The source of the XML payload.
2.  The `.xsl` stylesheet file to apply.
3.  The destination for the transformed output.

The plugin can be attached to the request flow (using the `access` phase) or the response flow (using the `body_filter` phase).

## Configuration

The plugin can be configured with the following parameters:

| Parameter                 | Required | Description                                                                                                             |
| ------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------- |
| `xsl_file`                | **Yes**  | The name of the XSLT stylesheet file located in the plugin's `xsl/` directory (e.g., `default.xsl`).                      |
| `xml_source`              | **Yes**  | Specifies the source of the XML. Can be `request_body`, `response_body`, or `shared_context`.                           |
| `xml_source_name`         | No       | Required if `xml_source` is `shared_context`. The key in `kong.ctx.shared` where the XML string is stored.              |
| `output_destination`      | **Yes**  | Specifies where to place the transformed output. Can be `replace_request_body`, `replace_response_body`, or `shared_context`. |
| `output_destination_name` | No       | Required if `output_destination` is `shared_context`. The key in `kong.ctx.shared` for storing the output.            |
| `content_type`            | No       | The `Content-Type` header to set when the body is replaced. Defaults to `application/xml`.                               |
| `on_error_continue`       | No       | If `true`, continues processing even if the transformation fails. Defaults to `false`.                                  |
| `on_error_status`         | No       | The HTTP status to return on failure if `on_error_continue` is `false`. Defaults to `500`.                              |
| `on_error_body`           | No       | The response body to return on failure if `on_error_continue` is `false`. Defaults to `XSL Transformation failed.`.     |
| `parameters`              | No       | An array of parameters to pass to the XSLT stylesheet. Each parameter object has: `name`, `value_from` (`literal` or `shared_context`), and `value`. |

### Parameters Array

The `parameters` array allows you to pass dynamic or static values into your XSLT stylesheet. Each element in the array is an object with the following fields:

*   `name`: The name of the `<xsl:param>` in your stylesheet.
*   `value_from`: Either `literal` (to use the `value` field directly) or `shared_context` (to retrieve the value from `kong.ctx.shared`).
*   `value`: The literal string value or the key name in `kong.ctx.shared`.

## Usage Example

### Scenario

Transform an incoming XML request body and replace it with the transformed content before it reaches the upstream service.

### Plugin Configuration

```yaml
plugins:
  - name: xsltransform
    config:
      xsl_file: "default.xsl"
      xml_source: "request_body"
      output_destination: "replace_request_body"
      content_type: "text/xml"
      parameters:
        - name: "static_param_name"
          value_from: "literal"
          value: "Hello from Kong"
```

### Request

**Incoming Request to Kong:**
```http
POST /service-a HTTP/1.1
Host: my-kong-gateway.com
Content-Type: application/xml

<customer>
  <id>123</id>
  <name>John Doe</name>
</customer>
```

### Result

The `xsltransform` plugin intercepts this request. Using the `default.xsl` stylesheet, it transforms the body. The upstream service will receive a request with the following body:

```xml
<transformed_data>
  <message>This is a default transformation.</message>
  <original_root_element>customer</original_root_element>
  <params>
    <input_param_value/>
    <static_param_value>Hello from Kong</static_param_value>
  </params>
  <original_content>
    <customer>
      <id>123</id>
      <name>John Doe</name>
    </customer>
  </original_content>
</transformed_data>
```