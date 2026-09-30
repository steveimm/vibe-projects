# Privacy Policy for PocketPilot

Effective date: 2026-10-01

PocketPilot (`id.steveimm.pocketpilot`) is an open source Android app for user-directed automation through Android Accessibility Service. PocketPilot is designed to run on your device and to send information only when it is needed to complete a task you explicitly start.

This policy is written for users and for Google Play review. It describes how PocketPilot handles data and how the app is intended to comply with the Google Play User Data policy.

## What data is collected

PocketPilot does not collect user data on PocketPilot-operated servers. The app does not include tracking, telemetry, analytics, advertising identifiers, or background profiling. PocketPilot does not operate a backend service that receives, stores, or sells your activity.

The app can store settings on your device so it can function. This includes your model server URL, model ID, and optional API key. Keys are stored locally and scoped to their server endpoint. Persistent API keys are stored using AndroidX Security `EncryptedSharedPreferences`, protected by a `MasterKey` using AES256_GCM.

PocketPilot can read the current screen only through the Android Accessibility Service permission that you enable. It uses that access to understand the visible interface and perform the actions you request. Task observations can include screenshots. Optional local traces and debug output can retain these screenshots on your device.

## What is sent to third parties

PocketPilot sends screen content and task context to the model server URL you configure, only during active task execution. The app has no default cloud endpoint, provider login, or cloud fallback.

Examples of sent data may include visible text on the screen, app UI structure, your typed task request, and recent action history needed to continue the task. PocketPilot sends this data only so the chosen provider can process the automation request. PocketPilot does not send this information to advertising, analytics, or tracking services.

Your API key never leaves your device except when it is used as an authentication header or credential for the LLM provider you selected. PocketPilot does not send your API key to PocketPilot developers, PocketPilot-operated servers, analytics services, or unrelated third parties.

The LLM provider you choose may process, retain, or log requests according to that provider's own terms and privacy policy. You are responsible for choosing a provider you trust and for managing any account or API-key settings with that provider.

## Permissions used and why

Accessibility Service: PocketPilot uses Android Accessibility Service to read the visible screen, inspect UI elements, and perform taps, swipes, and text entry on your behalf. This permission is required for automation. Automation stops when you stop the task or it completes. The accessibility service can remain connected to host the floating controls between tasks.

Display over other apps: PocketPilot uses the overlay permission to show the Smart Capsule while you are in other apps. The Smart Capsule displays task progress and controls such as pause, take over, and stop. This permission does not allow PocketPilot to record the screen.

Battery optimization or background running: PocketPilot may ask you to allow unrestricted battery use so longer tasks are not stopped by aggressive device battery management. This is used for task reliability, not for background monitoring.

## Data retention

PocketPilot does not retain user data on PocketPilot-operated servers because it does not collect user data server-side. Task screen content and task context are not stored by PocketPilot on a developer server.

On your device, PocketPilot may retain local settings, provider credentials, saved conversations, and enabled execution traces until you remove them, clear app data, or uninstall the app. Provider credentials are intended to remain on device except when sent to the selected provider as authentication for requests you initiate.

Third-party LLM providers may have their own retention practices for requests sent to them. Review your selected provider's privacy policy and account settings for details.

## How to delete your data

Because PocketPilot stores everything locally on your device and does not operate a backend, you can delete your data at any time without contacting the developer. Deletion is local and permanent once the action succeeds.

In-app deletion (granular):

- **Server API key** — clear the optional key in `Settings → Model server` and save. Keys are encrypted and scoped to each endpoint.
- **One chat** — choose Delete in the chat drawer. This stops any task using that chat and removes its saved conversation and resume data, including its displayed result and drafts.
- **All chats** — `Settings → Permissions & diagnostics → Clear chat history` stops current work and removes saved conversations, resume data, the current conversation, floating results, and drafts. Execution traces are separate.
- **Local traces** — `Settings → Permissions & diagnostics → Clear traces` stops current work and removes recorded execution traces, tool-call logs, and debug screenshots. Saved chats and displayed results remain available.

Full deletion:

- Open Android `Settings → Apps → PocketPilot → Storage → Clear data`. This removes all credentials, history, traces, and settings simultaneously.
- Uninstalling PocketPilot also deletes all local app data.

Prompts or screen content retained by your model server are governed by its configuration. Deleting local app data does not delete server-held copies.

## Children

PocketPilot is not directed to children under 13. The app is intended for users who can understand that it reads screen content and sends task context to their chosen LLM provider during active task execution.

## Google Play User Data policy compliance

PocketPilot's Google Play disclosures should state that the app does not collect user data on PocketPilot-operated servers, does not track users, and does not use analytics or telemetry. The only third-party data transfer described by this policy is user-directed processing by the LLM provider selected by the user during active task execution. PocketPilot's sensitive Android permissions are used to provide the app's core automation and overlay features.

## Contact

Project issue tracker: https://github.com/steveimm/vibe-projects/issues

Source code: https://github.com/steveimm/vibe-projects/tree/main/PocketPilot


## Voice input

PocketPilot uses Android’s on-device speech recognizer for dictation. The microphone is unavailable when that service is absent. There is no fallback to the default network speech recognizer. Recognized text becomes an editable draft and is sent to the configured model server only when submitted.
