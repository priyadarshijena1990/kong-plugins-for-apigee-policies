# Kong Plugin: parse_dialogflow_request

Extracts values from Dialogflow request JSON using dot-notation mappings and stores them in `kong.ctx.shared`.

## Features
- Configurable source (request body/shared context)
- Dot-notation mapping for extraction
- Stores extracted values for downstream use
