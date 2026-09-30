# PocketPilot UI and interaction review

Status: completed on the API 35 emulator, 2026-10-01.

## Completed changes

- Replaced repeated branding, decorative copy and oversized input with a compact chat layout. The composer starts at one line, grows to five lines, and supports Enter for newlines and Ctrl/Meta+Enter to send.
- Opening history, settings or another app releases input focus. Incoming questions cannot reopen the keyboard behind the drawer. Reopening history shows the latest chats after refresh without resetting a manual scroll while it remains open.
- Model server uses **Test** and **Save**. Test checks the unsaved endpoint and optional key through `/models`, with a three-second deadline, cancellation and retry. Removed the HTTP warning filler.
- The persistent bubble expands/minimizes the controls and can be dragged onto a bottom-center × to stop and dismiss them. The panel provides Open chat. Missed drops dock the bubble and preserve its position.
- Tasks can start directly from the overlay over an app the user opened. The service creates the session without opening MainActivity, and the first model request includes that current screen.
- Screen-off and keyguard remove all overlay windows, markers and the drag target. Active work pauses. Unlocking requires explicit Resume.
- The bubble stays interactive during injected gestures. Repositioning owns a temporary pause and resumes only that pause. Stop, dismissal and lock revoke that resume. The bubble moves clear of overlapping strokes. Controls remain interactive outside the gesture path, and the optional full-screen touch shield retains its policy.
- Android 14+ screenshot composition excludes accessibility overlays without hiding them. Unsupported or incomplete compositions retain the temporary suppression fallback. Bounded gesture markers and edge windows use physical display coordinates.
- Server failures leave usable input. Stop cancels pending transport and paused tasks. A stream containing only heartbeat comments fails after the no-output timeout.
- Setup distinguishes initial permission instructions from an unsuccessful settings return. Demo has Stop, safe immediate retry, failure recovery and optional skipping.
- Data deletion belongs to the session owner. Clear traces stops writers and deletes traces plus debug screenshots while retaining chats. Clear history also clears loaded conversations, drafts and floating results. Deleting one chat clears only its owners and files. A write barrier prevents pending saves from recreating deleted files.
- Approval prompts name the actual restricted app. Actions involving two cautious apps require consent for each. Fresh request IDs and package matching reject stale responses, including when a model reuses a tool-call ID. Blocked apps remain blocked.
- Dictation uses Android's on-device recognizer only. There is no remote fallback. Navigation, draft changes and lifecycle pauses cancel dictation and release the recognizer.
- Removed Termux integration, unused related dependencies, repository-provided skills, `.claude`, its aliases and obsolete setup helpers. Updated the relevant architecture and privacy documentation.

## Review checklist

- [x] One-line and multiline input, growth/shrink, newline preservation, draft retention and keyboard shortcuts.
- [x] Physical-keyboard toolbar and full docked phone keyboard, drawer focus handling and incoming questions.
- [x] Chat answers, Markdown, native reasoning, selection, scroll/Latest, failures and permission repair.
- [x] Settings home, server form and validation, Test states/model menu, automation, app access/search, diagnostics/data dialogs and licenses.
- [x] Setup permissions/details/return, granted states, server, demo running/Stop/retry/failure and completion.
- [x] Idle/running/paused/question/handoff/completed/error floating controls, Open chat and starting from the current app.
- [x] Drag target, missed drop, direct dismissal, active-gesture interruption, lock during drag, screenshot exclusion and reduced motion.
- [x] Light/dark, portrait/landscape, 150% text and long content.
- [x] Individual deletion and bulk clearing against isolated QA data, followed by a new request that cannot restore deleted context.
- [x] Correct foreground/destination approval subjects, including stale responses and two cautious apps.
- [x] Final signed ARM64 build identity and exact installed APK verification.
- [x] Restore original emulator chats, preferences, keyboard configuration and display settings.

## Evidence and limits

QA used a Pixel 8 API 35 ARM64 emulator and the signed release APK. Private screenshots, short recordings and an offline review gallery cover the inspected states. Historical before-fix captures are identified separately. Unchanged screens captured before later non-visual fixes are labeled accordingly.

A loopback fixture exercised real HTTP requests, native tools and app transitions. The user's model endpoint remained unreachable by both hostname and saved IP at the final connectivity check. These results establish UI and harness behavior, not local-model task capability. No physical OPPO verification was performed.

The final checks passed **941 release JVM tests**, release lint with zero errors, and Android instrumentation source compilation. Instrumentation tests were not executed. The emulator's on-device recognizer reported an unavailable language, so voice evidence covers permission/error/cancellation rather than successful transcription. Android app-ops recorded a completed 225 ms microphone use, with no active capture afterward.

Automatic approval review rejected activating Auto approve for QA. Its appearance was inspected with the existing Per app policy retained. Approval behavior is exercised through existing app classifications and isolated policy tests.

The API 35 lock test removed overlays after screen-off delivery in approximately 0.6 seconds. The visible keyguard was clean. Raw emulator touch-device events, rather than competing ADB synthetic swipes, verified that a user can interrupt an accessibility gesture to reposition or dismiss the bubble.

README promotional artwork remains outside this change. Private QA artifacts are kept outside the repository.

The release APK uses the existing signing key, contains only `arm64-v8a`, is non-debuggable, and passes 16 KB ZIP alignment. Its installed bytes match the build output. SHA-256: `67c9567d1d0edcefdfd0dc72b894b78ea15acd4185d966ccfefc1a8a03f4786d`.

After QA, all 84 original session/context files were byte-verified against their backups, including after relaunch. Original preferences, trace directories, display settings and hardware-keyboard configuration were restored. The test server and ADB reverse mapping were removed. The unrelated `cherry-diff/package-lock.json` modification was preserved unchanged.
