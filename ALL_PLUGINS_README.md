# Kong Plugins for Apigee Policies

## Environmental Dependencies & Requirements

These plugins require the following environment for proper operation:

- **Kong Gateway**: Kong Gateway Enterprise 3.12.0.0 (or compatible Kong versions)
- **Docker**: Required for running Kong and dependencies via Pongo
- **docker-compose**: Orchestrates containers in the Pongo test environment
- **curl**: Used by Pongo for network operations
- **realpath**: Needed for some environments (especially MacOS); install via coreutils if missing
- **Kong License**: For Kong Enterprise features, set the `KONG_LICENSE_DATA` environment variable
- **Database Dependencies**: Kong uses Postgres (default 9.5), but Cassandra and Redis are also supported and can be configured via environment variables (`POSTGRES`, `CASSANDRA`, `REDIS`)
- **Custom CA Certificates**: If plugins need to trust custom CAs, set `PONGO_CUSTOM_CA_CERT` to the path of your PEM file
- **Network/Proxy**: If running behind a proxy, configure Pongo to disable SSL verification (`PONGO_INSECURE`)

> Ensure all dependencies are installed and environment variables are set as needed for your deployment.

---

This document provides an overview of all custom Kong plugins mapped to Apigee policies, including their purpose, mapped Apigee policy, and key features. Each plugin is production-ready, validated, and tested for Kong Gateway Enterprise 3.12.0.0.

---

## Plugin YAML Configuration Table

| Plugin Name                | Example YAML Configuration |
|----------------------------|---------------------------|
| **generate_jwt**           | ```yaml\nplugins:\n- name: generate-jwt\n  config:\n    algorithm: HS256\n    secret_source_type: literal\n    secret_literal: "my-super-secret"\n    subject_source_type: literal\n    subject_source_name: "user-123"\n    issuer_source_type: literal\n    issuer_source_name: "my-kong-gateway"\n    expires_in_seconds: 3600 # 1 hour\n``` |
| **xml_to_json**            | ```yaml\nplugins:\n  - name: xml-to-json\n    config:\n      xml_source: "request_body"\n      output_destination: "replace_request_body"\n      content_type: "application/json; charset=utf-8"\n``` |
| **graphql_security_filter**| ```yaml\nplugins:\n- name: graphql-security-filter\n  config:\n    allowed_operation_types:\n    - query\n    block_patterns:\n    - "__schema"\n    - "__type"\n    block_status: 403\n    block_body: "Forbidden"\n``` |
| **json_to_xml**            | ```yaml\nplugins:\n  - name: json-to-xml\n    config:\n      json_source: "response_body"\n      output_destination: "replace_response_body"\n      root_element_name: "customer_data"\n      content_type: "application/xml; charset=utf-8"\n``` |
| **verify_jws**             | ```yaml\nplugins:\n- name: verify-jws\n  config:\n    jws_source_type: header\n    jws_source_name: Authorization\n    public_key_source_type: literal\n    public_key_literal: |\n      -----BEGIN PUBLIC KEY-----\n      MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...\n      -----END PUBLIC KEY-----\n    allowed_algorithms:\n``` |
| **raise_fault**            | ```yaml\nplugins:\n  - name: raise-fault\n    config:\n      status_code: 401\n      content_type: "application/json; charset=utf-8"\n      fault_body: '{"error": "Authentication Failed", "message": "Valid API Key is required."}'\n      headers:\n        X-Error-Identifier: "AUTH-001"\n``` |
| **hmac**                   | ```yaml\nplugins:\n- name: hmac\n  config:\n    mode: verify\n    secret_source_type: literal\n    secret_literal: "my-secret-key"\n    algorithm: HMAC-SHA256\n    signature_header_name: X-Signature\n    string_to_sign_components:\n    - component_type: method\n    - component_type: uri\n``` |
| **generate_jws**           | ```yaml\nplugins:\n- name: generate-jws\n  config:\n    payload_source_type: shared_context\n    payload_source_name: payload_for_jws # Assume a prior plugin created this table\n    private_key_source_type: literal\n    private_key_literal: "my-super-secret-for-hs256"\n    algorithm: HS256\n    jws_header_parameters:\n      kid: "service-key-1"\n    output_destination_type: header\n``` |
| **invalidate_cache**       | ```yaml\nplugins:\n- name: invalidate-cache\n  config:\n    purge_by_prefix: false\n    cache_key_prefix: "my-api:user-profile"\n    cache_key_fragments:\n    - "request.uri.segment[2]" # Assuming URI is /users/{user_id}\n    continue_on_invalidation: true\n``` |
| **json_threat_protection** | ```yaml\nplugins:\n- name: json-threat-protection\n  config:\n    source_type: request_body\n    max_array_elements: 100\n    max_container_depth: 10\n    max_object_entry_count: 50\n    max_string_value_length: 10000\n    on_violation_status: 400\n    on_violation_body: >\n      {\n``` |
| **xsltransform**           | ```yaml\nplugins:\n  - name: xsltransform\n    config:\n      xsl_file: "default.xsl"\n      xml_source: "request_body"\n      output_destination: "replace_request_body"\n      content_type: "text/xml"\n      parameters:\n        - name: "static_param_name"\n          value_from: "literal"\n          value: "Hello from Kong"\n``` |

## Plugin List & Details

### access_entity
- **Mapped Apigee Policy:** AccessEntity
- **Purpose:** Controls access to entities based on request parameters.
- **Key Features:** Entity validation, access control, error handling.

### assert_condition
- **Mapped Apigee Policy:** Condition
- **Purpose:** Evaluates Lua expressions to control request flow.
- **Key Features:** Conditional logic, abort/continue actions, custom error messages.

### concurrent_rate_limit
- **Mapped Apigee Policy:** ConcurrentRateLimit
- **Purpose:** Limits concurrent requests per key.
- **Key Features:** Rate limiting, key-based tracking, configurable limits.

### decode_jws
- **Mapped Apigee Policy:** DecodeJWS
- **Purpose:** Decodes and validates JWS tokens.
- **Key Features:** JWS parsing, signature verification, claim extraction.

### decode_jwt
- **Mapped Apigee Policy:** DecodeJWT
- **Purpose:** Decodes and validates JWT tokens.
- **Key Features:** JWT parsing, signature verification, claim extraction.

### delete_oauth_v2_info
- **Mapped Apigee Policy:** DeleteOAuthV2Info
- **Purpose:** Deletes OAuth v2 information from context or storage.
- **Key Features:** Context cleanup, token invalidation.

### external_callout
- **Mapped Apigee Policy:** ExternalCallout
- **Purpose:** Makes HTTP calls to external services during request processing.
- **Key Features:** HTTP callout, response handling, error management.

### flow_callout
- **Mapped Apigee Policy:** FlowCallout
- **Purpose:** Invokes sub-flows or external logic.
- **Key Features:** Flow invocation, context passing.

### generate_jws
- **Mapped Apigee Policy:** GenerateJWS
- **Purpose:** Generates JWS tokens for requests.
- **Key Features:** JWS creation, custom claims, header configuration.

### generate_jwt
- **Mapped Apigee Policy:** GenerateJWT
- **Purpose:** Generates JWT tokens for requests.
- **Key Features:** JWT creation, custom claims, header configuration.

### get_oauth_v2_info
- **Mapped Apigee Policy:** GetOAuthV2Info
- **Purpose:** Retrieves OAuth v2 information from context or storage.
- **Key Features:** Token retrieval, context access.

### google_pubsub_publish
- **Mapped Apigee Policy:** GooglePubSubPublish
- **Purpose:** Publishes messages to Google Pub/Sub.
- **Key Features:** Pub/Sub integration, message formatting.

### graphql
- **Mapped Apigee Policy:** GraphQL
- **Purpose:** Handles GraphQL requests and responses.
- **Key Features:** Query parsing, response formatting, security filtering.

### graphql_security_filter
- **Mapped Apigee Policy:** GraphQLSecurityFilter
- **Purpose:** Applies security rules to GraphQL operations.
- **Key Features:** Operation filtering, access control.

### hmac
- **Mapped Apigee Policy:** HMAC
- **Purpose:** Validates HMAC signatures on requests.
- **Key Features:** Signature verification, key management.

### invalidate_cache
- **Mapped Apigee Policy:** InvalidateCache
- **Purpose:** Invalidates cached data for requests.
- **Key Features:** Cache management, context cleanup.

### json_threat_protection
- **Mapped Apigee Policy:** JSONThreatProtection
- **Purpose:** Protects against JSON-based threats.
- **Key Features:** Payload validation, threat detection.

### json_to_xml
- **Mapped Apigee Policy:** JSONToXML
- **Purpose:** Converts JSON payloads to XML.
- **Key Features:** Data transformation, format conversion.

### key_value_map_operations
- **Mapped Apigee Policy:** KeyValueMapOperations
- **Purpose:** Interacts with key-value stores for request processing.
- **Key Features:** KVM access, local/cluster storage, namespace support.

### log_shared_context
- **Mapped Apigee Policy:** LogSharedContext
- **Purpose:** Logs shared context data for requests.
- **Key Features:** Context logging, custom formatting.

### mock_downstream
- **Mapped Apigee Policy:** MockDownstream
- **Purpose:** Mocks downstream service responses for testing.
- **Key Features:** Response mocking, scenario simulation.

### parse_dialogflow_request
- **Mapped Apigee Policy:** ParseDialogflowRequest
- **Purpose:** Extracts values from Dialogflow request JSON.
- **Key Features:** Dot-notation mapping, context storage.

### publish_message
- **Mapped Apigee Policy:** PublishMessage
- **Purpose:** Publishes messages to logging or external systems.
- **Key Features:** Message formatting, logging integration.

### raise_fault
- **Mapped Apigee Policy:** RaiseFault
- **Purpose:** Terminates request flow and returns custom error responses.
- **Key Features:** Status codes, custom fault bodies, header configuration.

### read_property_set
- **Mapped Apigee Policy:** ReadPropertySet
- **Purpose:** Reads property sets for request processing.
- **Key Features:** Property retrieval, context access.

### regular_expression_protection
- **Mapped Apigee Policy:** RegularExpressionProtection
- **Purpose:** Protects against threats using regex validation.
- **Key Features:** Pattern matching, threat detection.

### reset_quota
- **Mapped Apigee Policy:** ResetQuota
- **Purpose:** Resets quota counters for requests.
- **Key Features:** Quota management, counter reset.

### revoke_oauth_v2
- **Mapped Apigee Policy:** RevokeOAuthV2
- **Purpose:** Revokes OAuth v2 tokens.
- **Key Features:** Token revocation, context cleanup.

### saml_assertion
- **Mapped Apigee Policy:** SAMLAssertion
- **Purpose:** Validates and processes SAML assertions.
- **Key Features:** SAML parsing, signature verification, claim extraction.

### sanitize_model_response
- **Mapped Apigee Policy:** SanitizeModelResponse
- **Purpose:** Sanitizes model responses for security.
- **Key Features:** Response filtering, threat protection.

### sanitize_user_prompt
- **Mapped Apigee Policy:** SanitizeUserPrompt
- **Purpose:** Sanitizes user prompts for security.
- **Key Features:** Input filtering, threat protection.

### semantic_cache_lookup
- **Mapped Apigee Policy:** SemanticCacheLookup
- **Purpose:** Looks up values in semantic cache.
- **Key Features:** Cache lookup, context access.

### semantic_cache_populate
- **Mapped Apigee Policy:** SemanticCachePopulate
- **Purpose:** Populates semantic cache with values.
- **Key Features:** Cache population, context storage.

### service_callout
- **Mapped Apigee Policy:** ServiceCallout
- **Purpose:** Makes service callouts during request processing.
- **Key Features:** HTTP callout, response handling.

### set_dialogflow_response
- **Mapped Apigee Policy:** SetDialogflowResponse
- **Purpose:** Sets Dialogflow response values.
- **Key Features:** Response formatting, context update.

### set_integration_request
- **Mapped Apigee Policy:** SetIntegrationRequest
- **Purpose:** Sets integration request parameters.
- **Key Features:** Parameter setting, context update.

### set_oauth_v2_info
- **Mapped Apigee Policy:** SetOAuthV2Info
- **Purpose:** Sets OAuth v2 information in context or storage.
- **Key Features:** Token setting, context update.

### soap_message_validation
- **Mapped Apigee Policy:** SOAPMessageValidation
- **Purpose:** Validates SOAP messages for requests.
- **Key Features:** SOAP parsing, schema validation.

### statistics_collector
- **Mapped Apigee Policy:** StatisticsCollector
- **Purpose:** Collects statistics for requests.
- **Key Features:** Metrics collection, reporting.

### trace_capture
- **Mapped Apigee Policy:** TraceCapture
- **Purpose:** Captures trace data for requests.
- **Key Features:** Trace logging, context storage.

### verify_jws
- **Mapped Apigee Policy:** VerifyJWS
- **Purpose:** Verifies JWS tokens for requests.
- **Key Features:** JWS verification, claim extraction.

### xml_threat_protection
- **Mapped Apigee Policy:** XMLThreatProtection
- **Purpose:** Protects against XML-based threats.
- **Key Features:** Payload validation, threat detection.

### xml_to_json
- **Mapped Apigee Policy:** XMLToJSON
- **Purpose:** Converts XML payloads to JSON.
- **Key Features:** Data transformation, format conversion.

### xsltransform
- **Mapped Apigee Policy:** XSLTransform
- **Purpose:** Applies XSLT transformations to XML data.
- **Key Features:** XSLT processing, data transformation.

---

**All plugins are validated, tested, and production-ready. For configuration details and usage examples, see each plugin's individual README.md.**
