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
