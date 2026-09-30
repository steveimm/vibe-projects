# Overlay and connection reliability

Status: completed and verified on the Android 15 emulator. This continues the UI review with user feedback received after the initial refresh.

## Requirements and feedback

- [x] Replace screenshot-time overlay hiding where supported. Keep controls and action indicators visible without contaminating model screenshots.
- [x] Preserve full-display coordinates, keyboard/dialog content, orientation handling, protected-content behavior, and cancellation/resource cleanup.
- [x] Restore a restrained red control border and aligned tap/swipe feedback without large transparent overlay windows.
- [x] Keep a safe fallback for devices such as the OPPO Find X8. Emulator success alone does not verify OEM compatibility.
- [x] Provide an obvious return to PocketPilot from every expanded overlay state, including idle, running, questions, approvals, completion, and errors.
- [x] Let the user dismiss the bubble/panel without force-stopping the app. Distinguish minimize from close, stop active work when closing, and keep it dismissed until deliberately reopened.
- [x] Audit adjacent cases beyond reported examples: returning to chat during execution, pending approval/input, rapid toggles, rotation, permission loss, and a fresh task after failure/cancellation.
- [x] Bring Takeover and navigation controls into the app's blue theme.
- [x] A missing/disconnected/stalled model server must end in an actionable error, not indefinite Thinking.
- [x] Stop must promptly cancel connection setup, stream reading, retries, and paused/user-input states. It must not stay at Stopping.
- [x] Review controls together for size, spacing, hierarchy, contrast, keyboard behavior, dragging, clipping, and animation. Fix rough interactions before handing back for review.
- [x] Preserve the earlier minimalism direction: one logo, no decorative filler, no repeated explanations or redundant controls.
- [x] Keep Test connection and model selection working, preserve native reasoning, and remove replaced/dead code.
- [x] Validate behavior on the emulator using real app flows and controlled failure fixtures. Do not rely solely on builds or static inspection.
- [x] Restore original emulator configuration/chats, verify the signed ARM64 APK, and commit reviewed milestones.

## Working constraints

Work without subagents. Build only the signed ARM64 release when device verification needs it, using the existing signing key. Commit in stages and do not push without a request. Leave unrelated workspace changes untouched. Downscale captures before viewing. Avoid UI-automation dumps during active tasks or overlay checks because they can reconnect accessibility.

The model server may be offline. Deterministic local fixtures can test transport failures, tools, and UI transitions, but do not establish model capability. Keep private captures, traces, and device backups outside the repository.

## Initial findings

- The current display capture hides all overlays and waits 80 ms. Android 14's public `takeScreenshotOfWindow` excludes accessibility overlays, but it captures individual window surfaces. A prototype composes them in screen coordinates and falls back when geometry cannot be verified. Keyboard, system windows, dialogs, and transparent surfaces still need emulator verification.
- Border and gesture visualizers currently use display-sized WindowManager windows. Non-compact mode also adds a full-screen touch blocker. Both must be considered when addressing the OPPO failure.
- Open-app navigation is omitted in several accessibility overlay states, and required-action layouts suppress navigation entirely.
- Takeover uses the amber palette while most controls use blue.
- The streaming client makes a blocking request before it stores the cancellable stream handle. Stop can cancel the coroutine without interrupting connection setup. SDK retries stack with app retries, and default timeouts are too permissive for a dead server.

## Verification log

### Model reliability milestone

- Release JVM suite passed, including real socket tests for cancellation before headers, stalled streams, nonstreaming requests, takeover/resume, heartbeat-only streams, and bounded retries.
- Emulator: a silent server produced the actionable timeout error after 30 seconds. Open chat interrupted a stalled generation and opened the paused chat. Stop from that paused state completed immediately. Further device checks will use the final build.
- A launcher capture correctly detected missing transparent coverage and used the display fallback. Settings used native window capture, with the red border and controls visible to the user and absent from the model image.
- Close removed the error panel and bubble, which stayed dismissed. Completion now preserves the user's expanded state.

Other checklist items remain under review.


### Overlay verification

- Release checks: 897 JVM tests passed, release lint passed, and the device test sources compiled. UI checks use the signed ARM64 release on Android 15.
- A 2500 ms long press at normalized `[500, 450]` mapped to display `(540, 1080)`. WindowManager reported the 168 × 168 px marker at `[456, 996]–[624, 1164]`, centered exactly on that target. The underlying Settings row received the gesture.
- Four edge windows were 5 px thick on the test device. They adjusted to 2400 × 1080 after rotation. The controls stayed within 420 dp in landscape, and the bubble moved above an expanded panel after being dragged to the bottom.
- Shared answers survived minimize/reopen and Open chat. Takeover interrupts pending generation before opening chat. Stop from Paused completed without waiting for the server.
- Full-screen touch protection remains available and keeps its existing policy. Visual indicators are an independent setting, so restoring feedback does not require enabling the compatibility-sensitive touch shield.

- Active Close removed all overlay windows immediately. A dismissed idle bubble stayed absent after accessibility was disabled/re-enabled and Settings opened. Explicitly opening Main restored it.
- Heartbeat-only SSE traffic timed out after 30 seconds without model progress and retained the expanded error panel. Open chat and Close remained usable.
- Approval prompts kept navigation in the header and preserved the pending decision when switching to chat.


### Capture and gesture milestone

- Android 15 Settings and Settings search with the docked Gboard keyboard used native window capture without hiding controls. The keyboard's root bounds differed from its visible bounds, and exact buffer/root matching placed it correctly. Model images excluded the bubble and border.
- Launcher wallpaper used the transparency fallback. The notification shade used the system-panel fallback. Protected-window errors return no screenshot. Cancellation releases captured buffers and suppression leases.
- Gesture feedback now starts after the touch pass-through settling delay. Cancellation during that delay restores touchability, and cancelled/failed gestures remove their marker.
- Accessibility loss during a stalled request stopped the task and showed the permission-repair control. Re-enabling accessibility removed that prompt and restored the composer.
- An unreachable endpoint failed promptly with “Cannot reach the model server” and retained a usable composer.


### Keyboard refinement

A docked keyboard plus landscape and 1.3× text exposed input clipping. The panel now reserves room for the header and composer, and scrolls details and task buttons in the remaining space. Verified in portrait/landscape, light/dark themes, with the hardware keyboard toolbar, floating keyboard, and docked phone keyboard. Session approval now uses the same blue theme with lower visual emphasis than persistent approval.

Completed validation: 897 release JVM tests, release lint, device-test source compilation, signed ARM64 release installation, unreachable/stalled/heartbeat-only server failures, active/paused Stop, active and idle Close, persistent dismissal through service reconnects, pending question/approval/handoff navigation, draft preservation, rotation, dragging, rapid toggles, and permission loss/recovery.

The test server supplied deterministic responses. This validates the harness and interface, not local-model task competence. OPPO behavior remains a physical-device backlog item. Window capture intentionally retains display fallback for scenes that cannot be reconstructed faithfully, so those captures may still flicker.

Commits: `417f363` (model cancellation/timeouts), `aaa80c0` (floating controls and bounded indicators), `d5c216d` (window capture and gesture cleanup). The keyboard refinement follows separately.

Final tested APK SHA-256: `4c41c2c3151b11734ca241e233e9522bd6d73fb6663e7e4f84ccc807edd7cb4f`. Existing signing key, ARM64 only, non-debuggable, 16 KB ZIP alignment verified.


Restoration completed: four original preference files and 84 original session/context files were restored byte-for-byte. The 36 owned QA files and their traces were archived outside the repository and removed from the app. The original hardware-keyboard configuration and system settings were restored. The fixture server and ADB forwarding were stopped. The installed APK matches the final release hash above. Unrelated workspace changes were left intact.
