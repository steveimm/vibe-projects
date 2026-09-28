# Onboarding model server step

The wizard progresses through Accessibility, Overlay, Battery, Model server, Demo, and Complete. The Model server step uses the same `ModelServerForm` as Settings.

The user enters a valid HTTP(S) URL and model ID. The API key is optional. Saving persists the key for that endpoint and the server settings before calling `OnboardingViewModel.onServerConfigured()`. That method marks the step done and advances to the demo. Loading models is optional and queries only the entered endpoint.

A stored outcome never bypasses missing or invalid server settings. The step cannot be skipped. The optional demo rechecks accessibility, overlay permission, and server configuration before starting. Returning to server setup cancels the demo.

The persisted step key remains `step_api_key` to preserve prior onboarding progress. It stores only the step outcome, not a credential.
