# UI implementation

PocketPilot uses Kotlin, Jetpack Compose, and Material 3. Dependency versions are owned by `app/build.gradle.kts`.

## Main surfaces

| Source | Responsibility |
|---|---|
| `app/MainActivity.kt` | Activity entry, permission repair, session binding, saved draft/settings state |
| `app/MainActivityContent.kt` | Chat, settings, and capsule binding |
| `ui/chat/ChatScreen.kt` | History drawer, message list, composer, scrolling |
| `ui/chat/ChatViewModel.kt` | Chat state and session commands |
| `ui/chat/ChatEventReducer.kt` | Protocol events to chat updates |
| `ui/chat/ChatSessionHistoryController.kt` | List, open, and delete saved chats |
| `ui/chat/components/AgentRow.kt` | Activity disclosure, answer, stopped/error presentation |
| `ui/chat/components/AgentTrace.kt` | Native reasoning and tool execution details |
| `ui/chat/components/ChatMarkdown.kt` | Markdown rendering without remote image loading |
| `ui/navigation/NavigationDrawer.kt` | Saved chats and Settings entry |
| `ui/settings/SettingsSheet.kt` | Settings back stack and transitions |
| `ui/settings/ModelServerForm.kt` | Local endpoint, connection test, model selection, credentials |
| `ui/onboarding/OnboardingScreen.kt` | Setup steps and Android Back handling |

`RowState` distinguishes live, waiting, complete, stopped, and failed responses. Stopped responses retain partial output and persist their state. Final answers remain separate from native reasoning and tool results. User inspection or manual upward scrolling suspends automatic following. The down-arrow button returns to the bottom.

Tapping elsewhere in chat clears message text selection. The screen handles the press before child controls without consuming it, preserving long-press selection and button actions. A focused composer keeps its cursor and keyboard.

The main activity already handles orientation and theme changes in place. Font and display-size changes also retain the current interface. The saved instance state retains the composer draft and whether Settings was open.

## Floating controls

`CapsuleStateHolder` owns task state. `SmartCapsuleSurface` renders the shared controls in Main and overlays. The main chat displays completed/error output in its message list and keeps its composer available. Outside Main, the persistent bubble opens or minimizes the panel, including after completion.

`BubbleOverlayHost` owns raw-coordinate dragging, edge docking, and position preferences. `OverlayComposeHost` owns WindowManager attachment, lifecycle owners, visibility animation, and screenshot suppression. Its outer container controls screenshot visibility. Its content view owns animation. Closing releases touch interception immediately.

Touch protection stays off by default. The independent Action indicators setting uses four narrow border windows and a small moving gesture window. Android 14+ window capture excludes overlays where the scene can be composed faithfully. See [overlay behavior](overlay.md) for fallback and OEM limits.

## Permissions and model connection

`PermissionStateMonitor` distinguishes a selected accessibility service from a connected service. Main observes connection changes and refreshes permission state on resume. A service reconnect must not be labeled as disabled permission.

`ModelServerHttp` performs a cancellable GET to the configured API's `/models` route. It uses an optional bearer key, disables redirects, and enforces timeouts. `ModelCatalogRepository.testConnection` returns HTTP status and discovered models. An HTTP response can establish reachability even when authentication or model listing fails. The test does not save endpoint/key settings or generate a model response.

`ModelDiscovery` parses metadata. `ModelDiscoveryCache` scopes catalogs by endpoint. Manual model IDs remain supported when the server does not advertise models. Saving settings applies to new chats.

## Verification

Run release JVM tests and lint, then inspect the signed ARM64 build on the emulator. Compose instrumentation sources should compile when their related UI changes. Manual QA should cover chat, history, settings, permissions, setup, floating controls, light/dark themes, larger text, and landscape.

Use a local fixture server when the real model is unavailable. Fixture runs verify presentation and interaction, not model ability. Avoid `uiautomator dump` during active tasks or overlay-persistence checks because it can reconnect accessibility. Use screenshots and WindowManager/logcat evidence instead. Downscale captures before viewing them.
