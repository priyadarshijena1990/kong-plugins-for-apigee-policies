# Access Entity Plugin (access-entity)

The Access Entity plugin inspects the current request to identify the authenticated Kong Consumer and exposes the consumer's details to the request context (`kong.ctx.shared`). It is designed to replicate the functionality of Apigee's Access Entity policy.

This plugin is a utility that enables other plugins to make decisions based on the identity of the consumer. For example, a logging plugin could use this data to add the consumer's ID to logs, or a routing plugin could alter its behavior based on the consumer's group membership.

## Compatibility
This plugin is compatible with Kong Gateway 3.11 and above.

## Installation
1.  Copy the `access-entity` directory to your Kong plugins directory (e.g., `/usr/local/share/lua/5.1/kong/plugins/`).
2.  Add `access-entity` to the `plugins` list in your `kong.conf` file.
3.  Restart Kong.

## How it Works

The plugin operates in the `access` phase. It should be configured to run *after* any authentication plugins (e.g., `key-auth`, `jwt`, `oauth2`).

When it executes, it calls `kong.client.get_consumer()` to retrieve the authenticated consumer. If a consumer is found, the plugin gathers their details (including ID, username, and group memberships) and places them into a table in `kong.ctx.shared`.

## Configuration

The plugin has one simple configuration parameter:

| Parameter                 | Required | Description                                                                                             |
| ------------------------- | -------- | ------------------------------------------------------------------------------------------------------- |
| `context_variable_name`   | No       | The name of the variable in `kong.ctx.shared` where the consumer entity details will be stored. Defaults to `consumer_entity`. |

## Usage Example

### Scenario

You have an API that requires key authentication. After a consumer is authenticated, you want to log their `id` and `username`.

1.  **Attach `key-auth` plugin** to your route/service to handle authentication.
2.  **Attach `access-entity` plugin** to the same route/service.
3.  **Attach a logging plugin** (like `http-log`) that can read from `kong.ctx.shared`.

### `access-entity` Configuration

```yaml
plugins:
  - name: access-entity
    config:
      context_variable_name: "api_consumer"
```

### Example Request

Here's an example of a cURL request to an API with the `key-auth` and `access-entity` plugins enabled:

```sh
curl -i -X GET http://<your-kong-proxy-url>/api \
  --header 'apikey: <your-api-key>'
```

### Result

After a successful request with a valid API key, the `kong.ctx.shared` variable will contain the following structure, which can be accessed by subsequent plugins:

```lua
-- Example content of kong.ctx.shared.api_consumer
{
  id = "e7a75158-3b39-441c-9db9-5a9a6e33d53d",
  username = "my-app-user",
  custom_id = "user-123",
  groups = { "premium_users", "beta_testers" }
  -- ... and other fields like created_at, tags
}
```