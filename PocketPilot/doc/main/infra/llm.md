# Model server

PocketPilot uses one OpenAI-compatible Chat Completions server configured by the user. There are no built-in cloud providers, login flows, provider-specific model lists, or on-device inference engines.

## Configuration

Settings → Model server contains:

- **Server URL**: an HTTP(S) API base URL, such as `http://192.168.1.10:8000/v1`. A full `/chat/completions` URL is also accepted and normalized.
- **Model ID**: the exact ID served by the endpoint. Manual entry works without model discovery.
- **API key**: optional. Blank keys produce no Authorization header.

`AppSettingsStore` persists the URL and model together. It imports the former custom-server URL and selected/custom model ID, but never built-in cloud selections. `ServerCredentialStore` keeps keys encrypted and scoped to the normalized endpoint. Legacy custom-server keys migrate only to their original endpoint.

URLs containing credentials, query strings, or fragments are rejected. HTTP support does not disable HTTPS certificate verification in release builds.

## Requests and discovery

`ChatCompletionClient` requires an explicit base URL and sends `/chat/completions` requests, including streamed text and tool calls. No default endpoint or model is supplied by the application.

`ModelDiscovery` optionally requests `/models` from the entered endpoint. Discovered metadata is cached by server URL. `ModelCatalogRepository` supplies metadata for the session's endpoint and adds a manually entered model when it is absent from discovery. The session snapshot records its server URL and model ID.

The OpenAI Java SDK remains a protocol/serialization dependency. Its account login and Responses API clients are not used by the app.

## Lifecycle and retry

Each session factory owns its clients, including superseded credential generations, until teardown. `cleanupAll()` closes every owned client and prevents further creation. Child agents use the same configured endpoint and model as their parent.

Streaming producers run on IO and wait for channel capacity. Each collection owns its response. Cancellation closes that response and propagates without retrying or changing endpoints. Requests cancelled before the SDK returns headers close when their response becomes available.

`LlmRetry` and `StreamRetryRunner` handle transient transport errors. Streaming does not retry after partial output, preventing duplicate text or tool calls.
