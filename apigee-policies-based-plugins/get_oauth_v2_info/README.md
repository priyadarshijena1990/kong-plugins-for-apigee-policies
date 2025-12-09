# Kong Plugin: Get OAuth v2 Info

This plugin extracts information from the authenticated credential and consumer and places it into `kong.ctx.shared`. It is designed to mimic the functionality of Apigee's `GetOAuthV2Info` policy.

## Purpose

This plugin is a utility that should be run **after** a Kong authentication plugin (such as `oauth2` or `jwt`).

Authentication plugins in Kong populate the context with rich objects representing the authenticated `consumer` and `credential`. This `get-oauth-v2-info` plugin acts as an adapter, pulling specific fields from those objects and placing them into `kong.ctx.shared` under keys that you define.

This creates a stable interface for other custom plugins, so they don't need to know the complex structure of every possible credential object and can instead rely on simple, consistently named variables in the shared context.

## How it Works

The plugin runs in the `access` phase and uses the Kong PDK to access the authenticated consumer and credential:
- `kong.client.get_consumer()`
- `kong.client.get_credential()`

It then inspects these objects and copies values based on its configuration.

## Configuration

*   **`extract_client_id_to_shared_context_key`**: (string) If set, stores the `client_id` (for OAuth2) or `id` (for other credentials) of the credential in `kong.ctx.shared` under this key.
*   **`extract_app_name_to_shared_context_key`**: (string) If set, stores the `name` of the credential in `kong.ctx.shared`.
*   **`extract_end_user_to_shared_context_key`**: (string) If set, stores the `username` or `custom_id` of the consumer in `kong.ctx.shared`.
*   **`extract_scopes_to_shared_context_key`**: (string) If set, stores the `scope` associated with the token in `kong.ctx.shared`. It looks for the scope in the `X-Authenticated-Scope` header first, then falls back to `kong.ctx.authenticated_scope`.
*   **`extract_custom_attributes`**: (array of records) Allows you to extract any other field from the consumer or credential objects. It supports nested fields using dot notation (e.g., `custom_fields.role`).
    *   **`source_field`**: (string, required) The field name to extract (e.g., `name`, `custom_id`, `custom_fields.department`).
    *   **`output_key`**: (string, required) The key in `kong.ctx.shared` where the value will be stored.

### Example Usage

Imagine you have Kong's `oauth2` plugin enabled. You can add this plugin to run after it to normalize the credential information.

```yaml
# On a Service or Route
plugins:
- name: oauth2
  config:
    # ... your oauth2 config ...
- name: get-oauth-v2-info
  config:
    extract_client_id_to_shared_context_key: "auth_app_id"
    extract_scopes_to_shared_context_key: "auth_app_scopes"
    extract_end_user_to_shared_context_key: "auth_user_id"
```

After this plugin runs, another custom plugin can reliably access the following variables, regardless of what authentication method was used:
- `kong.ctx.shared.auth_app_id`
- `kong.ctx.shared.auth_app_scopes`
- `kong.ctx.shared.auth_user_id`
