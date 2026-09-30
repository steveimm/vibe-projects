# PocketPilot UI refresh

Status: ready for review, 2026-09-30.

## Result

PocketPilot now uses a cool light/dark palette, Geist typography, and a vector navigation mark. The empty chat has one logo in the header and compact editable suggestions above the composer. Removed the paper texture, serif identity, paw assets, decorative hero, repeated branding, filler copy, duplicate progress/error displays, and obsolete code/tests.

The model-server page has **Test connection**. It checks the current unsaved URL and optional key with a cancellable `/models` request. It reports reachability, authentication failures, HTTP errors, and network failures without generating a response or saving configuration. Advertised models appear in the Model ID selector. Manual IDs remain supported. Redirects are disabled, and the connection check has a ten-second deadline.

Termux was unnecessary for native Android automation. Removed its tool, bridge, permission, settings, startup probes, generated resource, and associated tests/docs. Removed the unused SnakeYAML dependency as well.

## Interaction fixes

- Settings has a back stack. Android Back handles the drawer, nested settings, and setup.
- New chats and history changes reset drafts and startup feedback. Font/display-size changes retain the interface, and activity state retains the draft.
- One activity disclosure contains native reasoning and tools. The answer stays visible independently. Inspecting reasoning stops automatic following, including when expanding a short response into a long trace.
- Stopping preserves partial output and remains distinct from completion in chat, history, and the floating controls.
- A task error leaves the composer available. A startup error preserves unsent input without adding duplicate synthetic messages.
- Permission repair distinguishes disabled accessibility from an enabled service reconnecting. Main observes reconnection while open.
- The persistent bubble retains drag, docking, input, and completion behavior. Docking and panel transitions animate. Screenshot hiding owns a separate outer container so animation cannot restore an overlay during capture.
- Reduced motion updates while the app is open. Removed the panel-local timer that reset when reopening the controls.
- Setup does not become complete merely because a server was saved. Privacy text reflects persistent floating controls.

## Verification

The actual LLM server remained offline. A temporary loopback fixture drove real app requests and tool execution for UI checks. These checks validate interaction and presentation, not model capability. No physical OPPO verification was performed in this pass.

| Area | Verified |
|---|---|
| Main and settings | Minimal home, one header logo, light/dark colors, server form, app access, diagnostics, licenses |
| Navigation | Drawer Back, nested Settings Back, new chat, rotation with drawer closed |
| Chat | Streaming, Markdown, scroll up/Latest, long reasoning disclosure, stopped partial answer, error recovery |
| User interaction | Question/reply, action-needed/Done, app approval opening Clock |
| Floating controls | Drag/dock, repeated expand/minimize, draft persistence, completed and stopped panels |
| Screenshots | Model screenshot excludes the bubble while the bubble remains on the emulator afterward |
| Layout | Portrait, landscape, 150% text, keyboard input, draft retention across rotation/text-size changes |
| Motion | Panel transitions, docking, disclosure, disabled system animations |
| Setup | Granted permission pages, keyless server configuration, demo failure detection, optional demo skip, completion |
| Connection test | Reachable and unreachable endpoints, missing/valid key, model selector, unchanged saved settings after testing |

All **902 release JVM tests** passed, release lint passed, and Compose instrumentation sources compiled. Emulator QA used the signed release APK. Network tests cover endpoint normalization, keyless/authenticated requests, catalog isolation, rejected authentication, redirects, missing model routes, cancellation, and timeout.

The final APK is `app/build/outputs/apk/release/app-arm64-v8a-release.apk`, signed with the existing key, ARM64-only, non-debuggable, and verified for 16 KB ZIP alignment. SHA-256: `2bbf531f9f8775c17186fd60aa3fcb0e4c7386c7f4a59586e8195dca54ac6361`.

## Cleanup and remaining scope

Restored the emulator's original server/preferences and display settings. All 84 original session/context files were verified against their backups. Removed only identified QA chats, fixture traces, and fixture catalog entries. Stopped the temporary server and removed its ADB port mapping. Private screenshots, traces, and backups remain outside the repository.

Compact overlays remain the default. The previously requested bounded border/gesture-marker redesign stays in the backlog. README promotional artwork remains outside this change.
