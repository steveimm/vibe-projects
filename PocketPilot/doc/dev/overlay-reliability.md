# Overlay and connection reliability

Status: in progress. This continues the UI review with user feedback received after the initial refresh.

## Requirements and feedback

- [ ] Replace screenshot-time overlay hiding where supported. Keep controls and action indicators visible without contaminating model screenshots.
- [ ] Preserve full-display coordinates, keyboard/dialog content, orientation handling, protected-content behavior, and cancellation/resource cleanup.
- [ ] Restore a restrained red control border and aligned tap/swipe feedback without large transparent overlay windows.
- [ ] Keep a safe fallback for devices such as the OPPO Find X8. Emulator success alone does not verify OEM compatibility.
- [ ] Provide an obvious return to PocketPilot from every expanded overlay state, including idle, running, questions, approvals, completion, and errors.
- [ ] Let the user dismiss the bubble/panel without force-stopping the app. Distinguish minimize from close, stop active work when closing, and keep it dismissed until deliberately reopened.
- [ ] Audit adjacent cases beyond reported examples: returning to chat during execution, pending approval/input, rapid toggles, rotation, permission loss, and a fresh task after failure/cancellation.
- [ ] Bring Takeover and navigation controls into the app's blue theme.
- [ ] A missing/disconnected/stalled model server must end in an actionable error, not indefinite Thinking.
- [ ] Stop must promptly cancel connection setup, stream reading, retries, and paused/user-input states. It must not stay at Stopping.
- [ ] Review controls together for size, spacing, hierarchy, contrast, keyboard behavior, dragging, clipping, and animation. Fix rough interactions before handing back for review.
- [ ] Preserve the earlier minimalism direction: one logo, no decorative filler, no repeated explanations or redundant controls.
- [ ] Keep Test connection and model selection working, preserve native reasoning, and remove replaced/dead code.
- [ ] Validate behavior on the emulator using real app flows and controlled failure fixtures. Do not rely solely on builds or static inspection.
- [ ] Restore original emulator configuration/chats, verify the signed ARM64 APK, and commit reviewed milestones.

## Working constraints

Work without subagents. Build only the signed ARM64 release when device verification needs it, using the existing signing key. Commit in stages and do not push without a request. Leave unrelated workspace changes untouched. Downscale captures before viewing. Avoid UI-automation dumps during active tasks or overlay checks because they can reconnect accessibility.

The model server may be offline. Deterministic local fixtures can test transport failures, tools, and UI transitions, but do not establish model capability. Keep private captures, traces, and device backups outside the repository.

## Findings

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


### Overlay verification in progress

- Release checks: 897 JVM tests passed, release lint passed, and the device test sources compiled. UI checks use the signed ARM64 release on Android 15.
- A 2500 ms long press at normalized `[500, 450]` mapped to display `(540, 1080)`. WindowManager reported the 168 × 168 px marker at `[456, 996]–[624, 1164]`, centered exactly on that target. The underlying Settings row received the gesture.
- Four edge windows were 5 px thick on the test device. They adjusted to 2400 × 1080 after rotation. The controls stayed within 420 dp in landscape, and the bubble moved above an expanded panel after being dragged to the bottom.
- Shared answers survived minimize/reopen and Open chat. Takeover interrupts pending generation before opening chat. Stop from Paused completed without waiting for the server.
- Full-screen touch protection remains available and keeps its existing policy. Visual indicators are an independent setting, so restoring feedback does not require enabling the compatibility-sensitive touch shield.

- Active Close removed all overlay windows immediately. A dismissed idle bubble stayed absent after accessibility was disabled/re-enabled and Settings opened. Explicitly opening Main restored it.
- Heartbeat-only SSE traffic timed out after 30 seconds without model progress and retained the expanded error panel. Open chat and Close remained usable.
- Approval prompts kept navigation in the header and preserved the pending decision when switching to chat.
