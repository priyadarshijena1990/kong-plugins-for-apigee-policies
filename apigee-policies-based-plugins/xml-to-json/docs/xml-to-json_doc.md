# Kong Plugin: XML to JSON Transformation

This plugin transforms an XML request or response body into a JSON body, mimicking the functionality of the Apigee XMLToJSON policy. It provides various configuration options to control the conversion process, such as handling XML namespaces, attributes, and text nodes.

## Abilities and Use Cases

### 1. Transform XML Request Body to JSON

**Ability:** Convert incoming XML payloads in API requests to JSON before they reach your upstream service.
**Use Case:** Your API consumers send requests with XML bodies, but your backend service expects JSON. This plugin allows seamless integration without modifying the client or the backend.

**Example Configuration (Request Phase):**
```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
  --data "name=xml-to-json" \
  --data "config.source=request" \
  --data "config.strip_namespaces=true" \
  --data "config.attribute_prefix=@" \
  --data "config.text_node_name=#text" \
  --data "config.pretty_print=true"
```

### 2. Transform XML Response Body to JSON

**Ability:** Convert XML payloads in API responses from your upstream service to JSON before sending them back to the client.
**Use Case:** Your backend service returns responses with XML bodies, but your client applications (e.g., mobile apps, web UIs) prefer or require JSON. This plugin ensures clients receive JSON without changes to the backend.

**Example Configuration (Response Phase):**
```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
  --data "name=xml-to-json" \
  --data "config.source=response" \
  --data "config.strip_namespaces=true" \
  --data "config.attribute_prefix=@" \
  --data "config.text_node_name=#text" \
  --data "config.pretty_print=true"
```

### 3. Handle XML Namespaces

**Ability:** Strip XML namespaces from elements during conversion.
**Use Case:** Simplify the resulting JSON structure by removing verbose namespace prefixes (e.g., `<soap:Body>` becomes `{"Body": ...}`).

**Example Configuration:**
Set `config.strip_namespaces=true` (default).

### 4. Customize Attribute and Text Node Conversion

**Ability:** Define prefixes for XML attributes and keys for XML text content in the resulting JSON.
**Use Case:** Control how XML structural elements (attributes like `id="123"`) and plain text content (`<value>100</value>`) are represented in JSON (e.g., "@id": "123" and "#text": "100").

**Example Configuration:**
Set `config.attribute_prefix="@"` (default) and `config.text_node_name="#text"` (default).

### 5. Force JSON Arrays for Specific Elements

**Ability:** Treat children of an XML element as a JSON array if the element's name ends with a specified string.
**Use Case:** When an XML structure might sometimes contain a single child and sometimes multiple, but you always want an array in JSON for consistency (e.g., `<item>` or `<item><item>`), you can define a suffix like `_list`.

**Example Configuration:**
```bash
curl -X PATCH http://localhost:8001/routes/{route_id}/plugins/{plugin_id} \
  --data "config.arrays_key_ending=_list" \
  --data "config.arrays_key_ending_strip=true"
```
If XML is `<items_list><item>A</item><item>B</item></items_list>`, it becomes `{"items": ["A", "B"]}`.

## Plugin Configuration

The `xml-to-json` plugin supports the following configuration parameters:

| Parameter               | Type    | Default             | Description                                                                                                                                                                                                             |
| :---------------------- | :------ | :------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `source`                | `string`| `"response"`        | Specifies whether to convert XML in the `request` or `response` body. Valid values are `"request"` and `"response"`.                                                                                                 | 
| `strip_namespaces`      | `boolean`| `true`              | When `true`, removes XML namespaces (e.g., `soap:`) from element and attribute names during conversion.                                                                                                                | 
| `attribute_prefix`      | `string`| `"@"`               | A prefix string to use for XML attributes when they are converted to JSON keys (e.g., `@id` for `<element id="value">`).                                                                                               | 
| `text_node_name`        | `string`| `"#text"`           | The key name to use for XML element text content when converted to JSON (e.g., `#text` for `<element>text</element>`).                                                                                                  | 
| `pretty_print`          | `boolean`| `false`             | When `true`, the output JSON will be formatted with indentation and newlines for readability.                                                                                                                         | 
| `content_type`          | `string`| `"application/json"`| The `Content-Type` header value to set for the transformed body.                                                                                                                                                      | 
| `remove_xml_declaration`| `boolean`| `false`             | When `true`, attempts to remove the XML declaration (e.g., `<?xml version='1.0'?>`) from the input string before parsing.                                                                                                | 
| `arrays_key_ending`     | `string`| `""`                | If an XML element's name ends with this string, its children will always be treated as a JSON array. For example, setting to `_list` will convert `<items_list><item>A</item><item>B</item></items_list>` to `{"items_list": ["A", "B"]}`. | 
| `arrays_key_ending_strip`| `boolean`| `false`             | If `arrays_key_ending` is used, setting this to `true` will strip the `arrays_key_ending` suffix from the JSON key name (e.g., `items_list` becomes `items`).                                                      | 

## Apigee Policy Mapping

This plugin directly maps to the functionality of the Apigee **XMLToJSON Policy**. The configuration options provided by this Kong plugin are designed to cover the most common transformation scenarios and settings available in the Apigee policy.

---
**Note:** This plugin relies on the `lua-xml` and `cjson` libraries, which are typically available in standard Kong installations.

## Next Steps

To deploy and test this plugin:
1.  Ensure the plugin files (`handler.lua`, `schema.lua`) are placed in the correct location (e.g., `/usr/local/share/lua/5.1/kong/plugins/xml-to-json/` on your Kong nodes).
2.  Enable the plugin globally or on a specific Service/Route/Consumer in Kong.
3.  Use the provided `pongo_validator.py` script with the plugin name (`xml-to-json`) to run the bundled tests and confirm functionality.
    ```bash
    python pongo_validator.py xml-to-json
    ```
    This command will utilize Pongo to set up a test environment, install the plugin, and run its `spec` tests. Any errors or failures in the test suite will indicate issues with the plugin's implementation.
