# Kong Plugin: mock_downstream

This plugin sets response headers based on values in `kong.ctx.shared` for testing or simulating downstream service responses.

## Features
- Sets headers for consumer info, subject, and groups
- Useful for context propagation and mock responses

## Usage
Attach to a route or service to simulate downstream header injection.
