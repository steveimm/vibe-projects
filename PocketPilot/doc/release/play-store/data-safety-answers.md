# Data-flow evidence

These notes describe the local-server-only implementation.

- Goals, relevant screen content, tool definitions, and requested screenshots are sent to the user-configured Chat Completions endpoint during a task. See `ChatCompletionClient` and `PromptBuilder`.
- Model discovery optionally calls `/models` on the entered endpoint. Saving configuration does not require discovery.
- There is no provider login, app account, bundled model catalog, cloud fallback, or on-device model downloader.
- Optional API keys are stored in encrypted preferences and scoped to the normalized endpoint. A blank key sends no Authorization header. See `ServerCredentialStore`.
- HTTP is supported for local servers, so model traffic is not necessarily encrypted. HTTPS uses normal certificate verification in release builds.
- Session history, memory, and optional traces remain in app storage. User-requested tasks and platform speech recognition can involve other apps or services.
- The configured server's own retention and network behavior depend on the user's deployment.

The source of truth for the connection UI is Settings → Model server. Privacy text is maintained in `PRIVACY_POLICY.md` and `doc/release/privacy/index.md`.
