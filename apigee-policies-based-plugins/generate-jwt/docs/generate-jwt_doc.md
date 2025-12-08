# GenerateJWT Kong Plugin

## Purpose

The `GenerateJWT` plugin for Kong Gateway allows you to generate a JSON Web Token (JWT) during the API flow. This mirrors the functionality of Apigee's `GenerateJWT` policy, enabling you to create secure, signed tokens for client authentication, inter-service communication, or custom security purposes.

**Important**: Due to the cryptographic complexities and the need for robust, battle-tested libraries, this plugin relies on an *external service* to perform the actual JWT generation and signing. The plugin gathers the necessary components (claims, signing key, algorithm, header parameters), sends them to this external service, and then processes the service's response to retrieve the signed JWT.

## Abilities and Features

*   **Claim Value Retrieval**: Extracts values for standard JWT claims (`sub`, `iss`, `aud`) and `additional_claims` from various sources:
    *   **`header`**: A specific request header.
    *   **`query`**: A specific query parameter.
    *   **`body`**: A field within a JSON request body.
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
    *   **`literal`**: A directly configured string.
*   **Signing Key Provisioning**: Provides the key required for signing from either:
    *   **`secret`**: For symmetric algorithms (HS256) from literal string or `kong.ctx.shared`.
    *   **`private_key`**: For asymmetric algorithms (RS256, ES256) from literal string or `kong.ctx.shared`.
*   **External Signing**: Makes an HTTP call to a configurable `jwt_generate_service_url` which handles the secure JWT generation and signing process.
*   **Configurable Algorithm**: Specify the JWT signing `algorithm` (`HS256`, `RS256`, `ES256`).
*   **Expiration Control**: Set `expires_in_seconds` to define the JWT's expiration time (`exp` claim).
*   **Custom JWT Header Parameters**: Allows adding custom `jws_header_parameters` (e.g., `kid` - Key ID, `typ` - Type).
*   **JWT Output Destination**: Stores the generated JWT string in a configurable destination:
    *   **`header`**: A specified request/response header.
    *   **`query`**: A specified query parameter.
    *   **`body`**: A field within a JSON request/response body (or replaces the entire body).
    *   **`shared_context`**: A specified key within `kong.ctx.shared`.
*   **Robust Error Handling**:
    *   Configurable `on_error_status` and `on_error_body` to return to the client if JWT generation fails.
    *   Option to `on_error_continue` processing even if generation fails.

<h2>Use Cases</h2>

*   **Client Authentication**: Issue JWTs for client applications to use for authenticating subsequent API requests.
*   **Inter-service Authorization**: Generate JWTs to assert identity and permissions when one microservice calls another.
*   **Custom Authentication Systems**: Create custom signed tokens as part of bespoke authentication and authorization workflows.
*   **Single Sign-On (SSO)**: Generate JWTs as security tokens for implementing SSO flows across multiple applications.
*   **API Gateway Security**: Enhance API security by issuing or forwarding JWT-based assertions.

<h2>Configuration</h2>

The plugin supports the following configuration parameters:

*   **`jwt_generate_service_url`**: (string, required) The full URL of the external service endpoint that will perform the JWT generation and signing. This service should accept claims, a signing key, algorithm, and header parameters, and return the generated JWT string.
*   **`algorithm`**: (string, required, enum: `HS256`, `RS256`, `ES256`) The JWT signing algorithm to use.
*   **`secret_source_type`**: (string, conditional, enum: `literal`, `shared_context`) Required if `algorithm` is `HS256`. Specifies where to get the symmetric secret key for signing.
*   **`secret_source_name`**: (string, conditional) Required if `secret_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the secret key string.
*   **`secret_literal`**: (string, conditional) Required if `secret_source_type` is `literal`. The actual symmetric secret key string.
*   **`private_key_source_type`**: (string, conditional, enum: `literal`, `shared_context`) Required if `algorithm` is `RS256` or `ES256`. Specifies where to get the asymmetric private key for signing.
*   **`private_key_source_name`**: (string, conditional) Required if `private_key_source_type` is `shared_context`. This is the key in `kong.ctx.shared` that holds the private key string.
*   **`private_key_literal`**: (string, conditional) Required if `private_key_source_type` is `literal`. The actual asymmetric private key string.
*   **`subject_source_type`**: (string, optional, enum: `header`, `query`, `body`, `shared_context`, `literal`) Specifies where to get the value for the standard `sub` (Subject) claim.
*   **`subject_source_name`**: (string, conditional) The name of the header/query parameter, JSON path for `body`, key in `kong.ctx.shared`, or literal value.
*   **`issuer_source_type`**: (string, optional, enum: `header`, `query`, `body`, `shared_context`, `literal`) Specifies where to get the value for the standard `iss` (Issuer) claim.
*   **`issuer_source_name`**: (string, conditional) The name of the header/query parameter, JSON path for `body`, key in `kong.ctx.shared`, or literal value.
*   **`audience_source_type`**: (string, optional, enum: `header`, `query`, `body`, `shared_context`, `literal`) Specifies where to get the value for the standard `aud` (Audience) claim.
*   **`audience_source_name`**: (string, conditional) The name of the header/query parameter, JSON path for `body`, key in `kong.ctx.shared`, or literal value.
*   **`expires_in_seconds`**: (number, optional) The time in seconds after which the JWT will expire. If omitted, the JWT might not have an 'exp' claim or will rely on the external service's default.
*   **`jws_header_parameters`**: (map, optional) Custom JWS header parameters (e.g., 'kid', 'typ'). These will be merged with the 'alg' header.
*   **`additional_claims`**: (array of records, optional) A list of custom claims to include in the JWT payload. Each record has:
    *   **`claim_name`**: (string, required) The name of the custom claim.
    *   **`claim_value_source_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`, `literal`) Specifies where to get the value for this custom claim.
    *   **`claim_value_source_name`**: (string, conditional) The name of the header/query parameter, JSON path for `body`, key in `kong.ctx.shared`, or literal value.
*   **`output_destination_type`**: (string, required, enum: `header`, `query`, `body`, `shared_context`) Specifies where to place the generated JWT string.
*   **`output_destination_name`**: (string, required) The name of the header or query parameter, the JSON path for a 'body' destination, or the key in `kong.ctx.shared` where the JWT string will be stored.
*   **`on_error_status`**: (number, default: `500`, between: `400` and `599`) The HTTP status code to return to the client if JWT generation or signing fails.
*   **`on_error_body`**: (string, default: "JWT generation failed.") The response body to return to the client if JWT processing fails.
*   **`on_error_continue`**: (boolean, default: `false`) If `true`, request processing will continue even if JWT generation or signing fails. If `false`, the request will be terminated.

<h3>Example Configuration (via Admin API)</h3>

**Enable on a Service to generate a JWT for inter-service communication using HS256 and a secret from shared context:**

```bash
curl -X POST http://localhost:8001/services/{service_id}/plugins \
    --data "name=generate-jwt" \
    --data "config.jwt_generate_service_url=http://jwt-signer.example.com/generate" \
    --data "config.algorithm=HS256" \
    --data "config.secret_source_type=shared_context" \
    --data "config.secret_source_name=service_secret_key" \
    --data "config.subject_source_type=shared_context" \
    --data "config.subject_source_name=authenticated_user_id" \
    --data "config.issuer_source_type=literal" \
    --data "config.issuer_source_name=api_gateway" \
    --data "config.expires_in_seconds=300" \
    --data "config.additional_claims.1.claim_name=user_roles" \
    --data "config.additional_claims.1.claim_value_source_type=shared_context" \
    --data "config.additional_claims.1.claim_value_source_name=user_permissions" \
    --data "config.output_destination_type=header" \
    --data "config.output_destination_name=X-Internal-JWT" \
    --data "config.on_error_continue=false" \
    --data "config.on_error_status=500" \
    --data "config.on_error_body=Internal JWT generation error."
```

**Enable on a Route to generate a JWT for client authentication using RS256 and a literal private key:**

```bash
curl -X POST http://localhost:8001/routes/{route_id}/plugins \
    --data "name=generate-jwt" \
    --data "config.jwt_generate_service_url=http://jwt-signer.example.com/generate" \
    --data "config.algorithm=RS256" \
    --data "config.private_key_source_type=literal" \
    --data "config.private_key_literal=-----BEGIN PRIVATE KEY-----MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDEc..." \
    --data "config.subject_source_type=query" \
    --data "config.subject_source_name=user_id" \
    --data "config.audience_source_type=literal" \
    --data "config.audience_source_name=client_app" \
    --data "config.expires_in_seconds=1800" \
    --data "config.output_destination_type=body" \
    --data "config.output_destination_name=access_token" \
    --data "config.on_error_continue=true"
```