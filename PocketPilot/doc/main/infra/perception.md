# Screen observations

Phone control uses the latest screenshot on every model request. Screenshot capture uses the complete display, including system dialogs, rather than selecting an accessibility window. PocketPilot briefly suppresses its own overlay windows during capture and restores them before compression, so controls do not conceal targets in model input. Images are resized to a maximum dimension of 1024 and compressed as JPEG at quality 70. Gesture coordinates are normalized to 0–1000, so resizing does not change their meaning.

The observation includes the foreground package and keyboard visibility. Missing screenshots are reported explicitly. Model-discovery metadata cannot silently suppress an image. Configure a local model that accepts image input through Chat Completions.

Accessibility remains the Android execution mechanism and provides focused text input, keyboard state, app-access masking, diagnostics, and sanitized trace data. Element indexes, text selectors, and bounds are not part of the model's action schema. Old transcript-only settings and checkpoint modes no longer affect observation capture.

Blocked app content is masked before model input. A screenshot that is unavailable or no longer matches display orientation cannot be used for a gesture.

See [phone actions](tool/phone_actions.md) and [agent loop](../agent/loop.md).
