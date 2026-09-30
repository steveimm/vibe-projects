# PocketPilot UI refresh

Status: in progress. This document records the scope and verification of the redesign requested on 2026-09-30.

## Intended result

PocketPilot should have its own identity, readable chat and reasoning, consistent controls, and smooth transitions. Replace the warm paper, serif typography, and paw branding with cool neutral surfaces, blue accents, sans-serif typography, and a navigation-inspired vector mark. Use the same identity in the launcher, onboarding, chat, settings, and floating controls.

Termux is outside the phone-automation workflow and will be removed, including its tool, bridge, permission, settings, startup probes, and obsolete tests and documentation. Native phone actions and the configured local model remain the core workflow.

## Completion checks

- [x] New vector logo and launcher icon, with no old app-brand assets left in use.
- [ ] Consistent light and dark palettes, typography, spacing, shapes, contrast, and system bars.
- [ ] Clear chat entry, history browsing, reasoning disclosure, action results, Markdown, and conversation controls.
- [ ] Coherent onboarding, local-server configuration, permission repair, settings navigation, and failure states.
- [ ] Persistent bubble and expanded controls use the new design and retain drag, input, screenshot, and gesture behavior.
- [ ] Fluid screen transitions, disclosure changes, input/keyboard behavior, and bubble interactions. Reduced motion remains usable.
- [ ] No clipping or inaccessible controls with a keyboard, larger font scale, or landscape layout.
- [x] Termux and related dead code removed, with native tool registration verified.
- [ ] Release checks pass and the signed ARM64 build is inspected on the emulator.
- [ ] Emulator configuration is restored after QA, and the user is notified when the result is ready for feedback.

## Verification approach

The user's model server is offline. Use saved sessions for existing conversation states and a temporary, deterministic local fixture server for streaming, questions, approvals, completion, and connection-failure UI. This validates presentation and interaction, not model capability. Preserve the user's emulator configuration and saved sessions. Screenshots, recordings, and private device backups stay outside the repository.

Review the actual screens and interaction outcomes before marking each check complete. Record findings and final evidence below as work progresses.

## Termux removal

The Termux integration exposed an optional Linux shell, workspace prompt, localhost bridge, and external command permission. Native phone tools use Android directly and have no dependency on it. Removed the integration, bridge source and generated resource task, settings entry, capability snapshot, and associated tests. Also removed the unused SnakeYAML dependency left behind by runtime skills, and regenerated the license inventory.

Validation: no Termux references remain in application source, active architecture docs, runtime scripts, or tool registration. All 907 remaining release unit tests pass, release lint passes, and device UI tests compile. No model server was used.

## Audit findings to finish

- The history drawer did not consume Android Back. Fixed and verified on the rebuilt emulator app.
- Header content inherited black in dark mode outside a Surface. Fixed with an explicit theme foreground and verified on the emulator.
- Nested settings navigation always returns to Settings home, including App access opened from Automation.
- New-chat, history switching, startup errors, and composer drafts need one consistent reset behavior.
- Streaming auto-scroll uses a cancellable effect with a mutable programmatic-scroll flag. Review interruption and manual reasoning expansion.
- The jump-to-bottom control says “live” even for completed history. Tool rows repeat their title inside a function-like label.
- Settings and permission copy mix implementation terms, capitalization, and redundant navigation controls.
- Overlay show/hide and edge docking are immediate. Animate them while keeping screenshot suppression independent of visual transitions.
- Reduced-motion settings are read only once. Update the preference reactively and verify disabled animations.
- Exercise streaming, interruption, questions, approvals, and errors with the local fixture server, then restore the original device configuration.

## Visual foundation

Replaced the paper texture, warm palette, serif identity, paw artwork, and density-specific launcher bitmaps with cool light/dark palettes, Geist typography, a shared navigation mark, and adaptive vector icons. Updated the home layout, editable suggestions, headers, message surfaces, settings cards, and floating mark. Removed the old paw animation and its implementation-only tests. Ordinary response completion no longer displays a success checkmark on the activity disclosure.

The first emulator review caught black header text in dark mode and Android Back exiting an open history drawer. Both were corrected and rechecked. The new logo is visible in the launcher, home, settings, and bubble. Light and dark home/settings screens were inspected, and tapping a suggestion was verified to fill the composer without creating a task. Main text, secondary text, primary buttons, and message-container foreground pairs have contrast ratios above 4.5:1 in both palettes.

Validation: 901 release unit tests, release lint, and device UI test compilation passed. Signed ARM64 release, existing certificate, non-debuggable flag, 16 KB alignment, and absence of Termux packaging checked. Foundation APK SHA-256: `cee420bb1b3573781fa1d0eb3971497825dc338772195aaa6cb30b0a75bce5aa`. Navigation depth, streaming behavior, motion, input focus, and the full state matrix remain in progress.
