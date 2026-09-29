# Local model harness verification

Tests use the Pixel 8 ARM64 emulator on Android 15 and the user-hosted `qwen3.8-27b` Chat Completions server. Goals are submitted through the release app's confirmation UI. Screenshots and traces are checked against the actual emulator display.

## Full-display screenshots

The baseline selected the highest accessibility window and called `takeScreenshotOfWindow`. It sent black 1024 × 125 images while ADB showed the normal 1080 × 2400 display. The model repeatedly reported a black screen and could not verify progress.

The capture pipeline now uses the display screenshot API. Accessibility roots are still used for tree inspection, but no longer choose the screenshot window. Late screenshot callbacks release their hardware buffers after cancellation.

Verification: the same "Open Settings" goal completed in three turns with three successful tool results. Captured images were 460 × 1024 and visibly contained the Settings screen. A separate ADB capture and UI tree confirmed the foreground app. The first turn still made an unnecessary coordinate tap, which remains evidence for the planned tool/schema simplification.

## Native reasoning instead of synthetic headings

Tool schemas no longer ask for `agent_thought`, and tool invocations no longer append generated explanations. The client streams the server's native `reasoning` or `reasoning_content` separately from assistant text and tool calls. Chat traces expose selectable text through Show/Hide model reasoning. History persists native reasoning, and trace artifacts contain the same reasoning. Old saved step captions remain readable as ordinary text.

Verification: 1,772 release unit tests passed, including both reasoning wire formats and chunk merging. Release lint and Android UI test compilation passed. In the emulator, the reasoning control expanded to the model's actual text. A clean "Open Settings" run completed in three turns with three successful tools and no errors.

Test setup note: avoid `uiautomator dump` during an active agent run. In this emulator it temporarily disconnects accessibility and interrupts the agent. Capture the live screen with `adb exec-out screencap -p` and inspect trace files, then inspect the UI tree after completion. An initial Clock run was interrupted by this test setup behavior while awaiting app approval and is not counted as a successful task.

## Single-agent execution

Removed the delegation tool, child runtime, role registry, child-only service copying, lifecycle events, prompt instructions, and replay hierarchy. The runtime now resolves one definition against enabled capabilities. Eval configuration no longer sends the unused agent mode field.

Verification: 1,757 release tests and 127 Python tooling tests passed. UI tests compiled, and replay JavaScript syntax checks passed. The signed ARM64 build completed "Open Settings" through the emulator in three turns with three successful tools and no errors. The captured prompt contains no delegation instructions.

## Reasoning on subsequent requests

The deployed server's tokenize endpoint confirms that assistant `reasoning` is retained in its rendered prompt, including before a new screen observation. The same server ignores `reasoning_content` on input. The app therefore preserves the reasoning field used by the server rather than changing it to another alias.

Native reasoning now survives the turn result, conversation history, runtime checkpoint, prompt assembly, and Chat Completions serialization. The HTTP integration test verifies both supported field names alongside their assistant tool call and matching tool response after checkpoint serialization. Token estimation includes the reasoning text.

Verification: 1,725 release tests passed. The combined shell-removal/reasoning-history build completed "Open Settings" in two turns with two successful tools and no errors. The emulator checkpoint retained 645 and 399 characters of native reasoning from its two assistant turns.

## Restricted shell removal

Removed the app-process shell implementation, registration, tool identifier, prompt instructions, and tests. Removed browser helper assets and instructions that depended on reading snippets through that tool. Optional `termux_shell` remains independently gated by actual Termux availability.

Verification: the combined release suite passed 1,725 tests, UI tests compiled, and the signed ARM64 build completed the two-turn Settings task described above. No restricted shell tool remains in the runtime roster. The final Settings screen was verified separately from tool success messages.

## Initial observation after goal confirmation

A baseline image showed the external-goal dialog still closing after Run had been pressed. The model's first tap corresponded to that button in normalized screenshot coordinates. Confirmed goals now use the existing delayed dispatch path, allowing the dialog to disappear before the first capture.

Verification: the emulator's first model image no longer contained the dialog, and "Open Settings" completed in two turns without a redundant tap. This was tested in the reduced-tool build; the launch change is independent of tool registration.

## Reduced phone-automation tool set

Removed todo/scratchpad state, persistent memory and automatic recall, runtime skills, browser scripting, their settings surfaces, and related tests, assets, and dependencies. App Access now manages only access rules. User handoff and optional Termux commands remain. Conversation history and native reasoning provide the model's retained context.

Verification: 1,135 release tests passed, release lint passed, and UI tests compiled. The emulator completed "Open Settings" in two turns with two successful tools and no errors. The second request's trace contains the first assistant turn's native reasoning. Settings no longer shows Memory or skill controls, and changing Clock to Allow through App Access persisted the expected override. Python tooling tests passed (125 tests).

## Native task completion

Removed the completion tool, completion arbitration, raw-text tool recovery, and synthetic success/failure classification. A nonblank native assistant answer with `finish_reason=stop` and no tool calls ends the task. Reasoning-only, empty, truncated, filtered, and unterminated responses fail instead. Structured tool calls continue execution. Stored legacy outcome names load as `FINISHED` without inventing a success verdict.

Trace summaries use stable `finished`, `error`, and `user_stopped` labels in the minified release. Evaluation reads the native final text and relies on independent scripted checks for success. Onboarding verifies that Settings actually opened before reporting demo success.

Validation: 1,116 release unit tests passed, release lint passed, device UI tests compiled, and the signed ARM64 release installed on the API 35 emulator. With `qwen3.8-27b`, an explicit `open_app` Settings request completed in 3 turns with 2 successful calls and a final answer. The screen showed Android Settings. Opening the absent `ZyphraTestApp927` completed in 2 turns with 1 failed call and a final explanation of the missing app, recorded as `finished`, not success.

The first natural-language Settings run still chose `mobile_action(action=open_app)` and then incorrectly concluded app opening was unavailable. This remains evidence for the next action-schema simplification, not a successful task result.

## Approval and overlay corrections found during gesture testing

The Settings search component has no package label visible to PocketPilot. The old approval handler treated that metadata lookup failure as a user denial. Approval now displays the package name when its label is unavailable. This keeps the access decision with the user.

After an accessibility-service reconnect while MainActivity was open, a new overlay controller could retain its default `MAIN_APP` location. Its hidden callback returned early because it had not seen the earlier visible callback. The hidden callback now updates location even in that reconnect state. The emulator reproduced this during QA setup, and the corrected build displayed the approval capsule over Settings search.

With the request to enable Dark theme, the local model opened Settings, searched, tapped the result, changed the setting, waited, and returned a native final answer. The run finished in 7 turns with 6 successful calls and no tool failures. Android's independent `cmd uimode night` check reported `yes`.

## Explicit phone actions and unobstructed observations

Replaced the overloaded action selector with `tap`, `long_press`, `swipe`, and `type_text`. Gestures use integer coordinates from 0 to 1000 over the whole screenshot, mapped to physical display pixels. Text entry replaces the focused field after a separate tap. Missing screenshots, orientation changes, invalid JSON, unknown fields, wrong types, unavailable tools, and out-of-range values produce explicit feedback before any action. Multiple tool calls are rejected together with a result for every call ID. Requests set `parallel_tool_calls=false`.

Removed semantic target resolvers, action retry/fallback executors, transcript-only and hybrid modes, unused vision-capability inference, obsolete debug tooling, and associated tests and documentation. The configured server always receives the current screenshot. Native reasoning remains in subsequent assistant history. App approval and launch share the same installed-app resolution, so an alias cannot approve a different package from the one launched. Cancellation now propagates while router tracking and screenshot resources are released.

Full-display capture initially included PocketPilot's controls, hiding the bottom rows. A scrolling test entered System instead of the obscured About page and kept searching beneath the overlay. That run was stopped and is not counted as a pass. Capture now temporarily suppresses the capsule, island, glow, and gesture markers, restoring them before image compression. The model receives an unobstructed display while user controls remain available between captures. Missing or cancelled captures also release suppression.

Validation on the Android 15 ARM64 emulator with `qwen3.8-27b`:

- Natural-language Settings launch: 2 turns, 1 successful call, no failures.
- Enable Dark theme using Settings search: 7 turns, 6 successful calls, no failures, independently verified with Android UI-mode state.
- Scroll through Settings, open About emulated device, read Android version: 7 turns, 6 successful calls, no failures, 42 seconds. The model reported Android 15, matching `ro.build.version.release`.
- The final About run's screenshots visibly exclude PocketPilot overlays; an ADB capture during execution confirms the controls are restored on the user's screen.
- 974 release unit tests passed, release lint passed, device UI tests compiled, and the signed ARM64 release installed. Python suites passed 120 tests plus 22 Termux bridge tests. The ADB helper checks passed 19 cases. Replay JavaScript syntax and repository whitespace checks passed.

The remaining acceptance check is a saved contact with multiple values, followed by reopening and verification.
