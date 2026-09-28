# Onboarding wizard

`OnboardingViewModel` advances through Accessibility → Overlay → Battery → Model server → Demo → Complete.

Permission outcomes and completion are persisted by `OnboardingStore`. Live accessibility and overlay checks override saved outcomes. Battery and the demo may be skipped. Model-server setup requires a valid URL and model ID, with no API-key requirement.

Returning from accessibility Settings polls briefly for the service to bind. Going back cancels pending advancement. Demo startup rechecks required permissions and server settings. Demo cancellation and navigation stop its temporary session.

The model-server step shares its form with Settings. See [Model server step](onboarding_model_server_step.md). Existing `step_api_key` outcomes are retained as the storage key for this step, but do not replace missing server configuration.

Debug intents can bypass the wizard for automated tests. Release intents cannot overwrite configuration or grant approvals, and external goals require user confirmation.
