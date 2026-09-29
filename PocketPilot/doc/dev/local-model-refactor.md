# Local model harness verification

Tests use the Pixel 8 ARM64 emulator on Android 15 and the user-hosted `qwen3.8-27b` Chat Completions server. Goals are submitted through the release app's confirmation UI. Screenshots and traces are checked against the actual emulator display.

## Full-display screenshots

The baseline selected the highest accessibility window and called `takeScreenshotOfWindow`. It sent black 1024 × 125 images while ADB showed the normal 1080 × 2400 display. The model repeatedly reported a black screen and could not verify progress.

The capture pipeline now uses the display screenshot API. Accessibility roots are still used for tree inspection, but no longer choose the screenshot window. Late screenshot callbacks release their hardware buffers after cancellation.

Verification: the same "Open Settings" goal completed in three turns with three successful tool results. Captured images were 460 × 1024 and visibly contained the Settings screen. A separate ADB capture and UI tree confirmed the foreground app. The first turn still made an unnecessary coordinate tap, which remains evidence for the planned tool/schema simplification.
