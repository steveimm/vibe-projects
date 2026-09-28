# Onboarding state

The wizard keeps permission state separate from model-server configuration and demo execution.

- `PermissionStepState` represents checking, opening Settings, success, and a missing permission. Accessibility and overlay are required. Battery optimization can be skipped.
- `ModelServerForm` owns the editable URL, model ID, optional key, discovery progress, and validation messages. The wizard advances only after valid settings have been saved.
- `DemoStepState` represents ready, running, success, and failure. A failure can return to server setup. The demo is optional.

See [Model server step](onboarding_model_server_step.md) and [Wizard](onboarding_wizard.md).
