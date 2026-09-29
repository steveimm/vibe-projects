---
name: action-debug
description: Debug phone action failures by comparing model gesture calls, accessibility execution, and an ADB baseline.
---

# Action debugging

Use this when the chosen target appears correct but the phone does not perform the expected action. Use `/cog-tune` for model decisions and prompt/history problems.

1. Read the run's `trace.jsonl`, the failing `tool_call_args` and `tool_result` artifacts, and the preceding screenshot. Correlate by call ID and turn number.
2. Check the current [phone action contract](../../../doc/main/infra/tool/phone_actions.md). The model calls `tap`, `long_press`, `swipe`, or `type_text` directly. It sends at most one call per response, with no calls in its final answer, and gestures use normalized coordinates from 0 to 1000.
3. Convert gesture coordinates to display pixels with `round(value / 1000 * (dimension - 1))`. Use `adb shell wm size` for the real display. Do not pass normalized values directly to `adb input` or the platform debug harness.
4. Stop the active model task before manual reproduction. Restore the same screen, then compare ADB input with accessibility gesture injection. Verify actual before/after screens rather than relying on action acceptance alone.
5. Fix the responsible layer and rerun the original model task. Record the request, model call, physical coordinates, observed result, and limitation.

## Direct platform checks

`scripts/action-test.sh` accepts physical pixels. `--adb` uses ADB input. Without it, the debug receiver requires a debug build. Use a development build only when this direct receiver is needed.

```bash
./scripts/action-test.sh tap --x 540 --y 1200 --adb --tag baseline
./scripts/action-test.sh tap --x 540 --y 1200 --tag accessibility
./scripts/action-test.sh swipe --start-x 540 --start-y 1800 --end-x 540 --end-y 600 --adb
```

Reset the UI between trials. Sequentially applying two taps is not a valid comparison unless the first tap leaves the screen unchanged.

## Evidence and boundaries

- Downscale screenshots before viewing them. Keep raw captures as artifacts.
- Do not run `uiautomator dump` during an active model task. It can disrupt the app's accessibility connection. Use screencap, logcat, and trace files during execution.
- A successful gesture dispatch does not prove the task succeeded. Inspect the resulting UI and field values.
- Missing screenshots, orientation changes, malformed arguments, multiple calls, and app-access denials intentionally reject execution.
- `type_text` replaces the focused field. Check focus and the resulting value.

Owners: `tool/impl/TouchTools.kt`, `tool/ToolParameters.kt`, `tool/ToolRouter.kt`, `platform/AccessibilityGestureInjector.kt`, `platform/NodeActionPerformer.kt`, and `platform/OverlayTouchGate.kt`.

See [trace extraction](references/trace_extraction.md).
