# SanitizeUserPrompt Kong Plugin

## Purpose

The `SanitizeUserPrompt` plugin for Kong Gateway is designed to clean and validate user-provided text inputs (prompts) before they are processed by upstream services. This is particularly useful for enhancing security by mitigating common attack vectors (like XSS or SQL injection) and ensuring data quality and consistency for applications that consume user input, such as AI/LLM services.

The plugin extracts a prompt from a configurable source, applies a series of sanitization rules, and then places the cleaned prompt into a specified destination. It can also block requests that contain malicious patterns.

## Abilities and Features

*   **Flexible Prompt Source**: Extracts the user prompt from:
    *   **`header`**: A specific request header.
    *   **`query`**: A specific query parameter.
    *   **`body`**: A field within a JSON request body (supports simple dot-notation paths).
*   **Configurable Sanitization Rules**: Apply one or more rules to clean the prompt:
    *   **`trim_whitespace`**: Remove leading and trailing whitespace.
    *   **`remove_html_tags`**: Strip basic HTML/XML tags.
    *   **`replacements`**: Define an array of regular expressions and their replacement strings to modify the prompt (e.g., to replace sensitive words).
    *   **`max_length`**: Truncate the prompt if it exceeds a specified maximum length.
*   **Request Blocking**: Configure `block_on_match` with regex patterns. If any pattern matches the sanitized prompt, the request will be immediately blocked with a configurable HTTP status and response body.
*   **Flexible Prompt Destination**: Places the sanitized prompt into:
    *   **`header`**: A specified request header.
    *   **`query`**: A specified query parameter.
    *   **`body`**: A field within a JSON request body (supports simple dot-notation paths) or replaces the entire body.
    *   **`shared_context`**: A specified key in `kong.ctx.shared` for use by other plugins.

<h2>Use Cases</h2>

*   **Security Hardening**: Protect backend services from various forms of injection attacks (XSS, SQL injection) by removing or neutralizing potentially harmful characters and patterns from user input.
*   **AI/LLM Prompt Cleansing**: Ensure prompts sent to AI or Large Language Models are clean, consistent, and adhere to specific formats, improving model performance and reliability.
*   **Data Quality Enforcement**: Enforce specific length limits or character sets for user-submitted content.
*   **Sensitive Data Removal**: Replace or remove sensitive information from user inputs before logging, storing, or forwarding to third-party services.
*   **Input Validation**: Act as an early gate for invalid or suspicious user inputs, preventing them from reaching downstream systems.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`source_type`**: (string, required, enum: `header`, `query`, `body`) Specifies where to extract the user prompt from.
*   **`source_name`**: (string, required) The name of the header or query parameter, or a dot-notation JSON path (e.g., `user.message` or `.` for the entire body) for a `body` source.
*   **`destination_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`) Specifies where to place the sanitized prompt.
*   **`destination_name`**: (string, required) The name of the header or query parameter, a dot-notation JSON path for a `body` destination, or the key for `shared_context`. If `destination_type` is `body` and `destination_name` is `.` or `""`, the entire request body will be replaced.
*   **`trim_whitespace`**: (boolean, default: `true`) If `true`, leading and trailing whitespace will be removed from the prompt.
*   **`remove_html_tags`**: (boolean, default: `false`) If `true`, simple HTML/XML tags (e.g., `<script>`, `<b>`) will be removed from the prompt.
*   **`max_length`**: (number, optional) If set, the prompt will be truncated to this maximum length if it exceeds it.
*   **`replacements`**: (array of records, optional) A list of regular expression `pattern` and `replacement` string pairs. The patterns are applied sequentially.
    *   Each record has: `pattern` (string, required, Lua/Nginx regex) and `replacement` (string, required).
*   **`block_on_match`**: (array of strings, optional) A list of regular expression patterns. If *any* of these patterns match the sanitized prompt, the request will be blocked.
*   **`block_status`**: (number, default: `400`, between: `400` and `599`) The HTTP status code to return when a request is blocked due to a matching `block_on_match` pattern.
*   **`block_body`**: (string, default: `"Invalid input detected."` ) The response body to return when a request is blocked.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to sanitize a query parameter and put it in a header:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=sanitize-user-prompt" \
    --data "config.source_type=query" \
    --data "config.source_name=prompt" \
    --data "config.destination_type=header" \
    --data "config.destination_name=X-Sanitized-Prompt" \
    --data "config.trim_whitespace=true" \
    --data "config.remove_html_tags=true" \
    --data "config.max_length=200"
```

**Enable on a Route to sanitize a JSON body field, apply replacements, and block on malicious patterns:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=sanitize-user-prompt" \
    --data "config.source_type=body" \
    --data "config.source_name=message" \
    --data "config.destination_type=body" \
    --data "config.destination_name=cleaned_message" \
    --data "config.trim_whitespace=true" \
    --data "config.replacements.1.pattern=email@example.com" \
    --data "config.replacements.1.replacement=[REDACTED_EMAIL]" \
    --data "config.block_on_match.1=(<script>.*</script>)" \
    --data "config.block_on_match.2=(SELECT.*FROM)" \
    --data "config.block_status=403" \
    --data "config.block_body=Forbidden: Malicious input detected."
```

**Sanitizing the entire request body and storing in shared context:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=sanitize-user-prompt" \
    --data "config.source_type=body" \
    --data "config.source_name=." \
    --data "config.destination_type=shared_context" \
    --data "config.destination_name=raw_sanitized_input" \
    --data "config.remove_html_tags=true" \
    --data "config.max_length=500"
```