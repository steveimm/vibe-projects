# Screen observations

A new user message begins with conversation history only. The model requests `read_screen` when it needs current phone state, or uses `open_app` directly. Phone actions then receive fresh screenshots. Conversation-only replies do not capture or send the screen. Screenshot capture retains full-display dimensions. On Android 14+, visible window surfaces can be composed at their exact screen positions while excluding accessibility overlays. Unsupported or incomplete compositions use full-display capture with temporary overlay suppression, so controls do not conceal targets in model input. Images are resized to a maximum dimension of 1024 and compressed as JPEG at quality 70. Gesture coordinates are normalized to 0–1000, so resizing does not change their meaning.

The observation includes the foreground package and keyboard visibility. When an image is available, up to 24 sanitized labels identify visible enabled interactive controls. They are hints for exploration, not alternate targeting parameters; gestures still use screenshot coordinates. PocketPilot is identified as the assistant’s own interface. Historical screen observations are labeled as previous observations, and a new user message does not reuse them as its current screen. Missing screenshots are reported explicitly. Model-discovery metadata cannot silently suppress an image. Configure a local model that accepts image input through Chat Completions.

Accessibility remains the Android execution mechanism and provides focused text input, keyboard state, app-access masking, diagnostics, and sanitized trace data. Element indexes, text selectors, and bounds are not part of the model's action schema. Old transcript-only settings and checkpoint modes no longer affect observation capture.

Blocked app content is masked before model input. A screenshot that is unavailable or no longer matches display orientation cannot be used for a gesture.

Window capture requires stable geometry, exact image-to-window dimensions, and complete opaque coverage. Overlapping app windows, magnification, system panels covering content, transparent wallpaper, and unavailable captures fall back to display capture. Secure windows return no image. Only the fallback hides the capsule, bubble, border, and markers for an 80 ms rendering allowance before the bounded Android callback. This delay is not a frame-completion guarantee. See [overlay capture](../ui/overlay.md#capture-and-touch-handling) for details.

See [phone actions](tool/phone_actions.md) and [agent loop](../agent/loop.md).
