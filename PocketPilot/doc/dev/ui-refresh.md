# PocketPilot UI refresh

Status: in progress. This document records the scope and verification of the redesign requested on 2026-09-30.

## Intended result

PocketPilot should have its own identity, readable chat and reasoning, consistent controls, and smooth transitions. Replace the warm paper, serif typography, and paw branding with cool neutral surfaces, blue accents, sans-serif typography, and a navigation-inspired vector mark. Use the same identity in the launcher, onboarding, chat, settings, and floating controls.

Termux is outside the phone-automation workflow and will be removed, including its tool, bridge, permission, settings, startup probes, and obsolete tests and documentation. Native phone actions and the configured local model remain the core workflow.

## Completion checks

- [ ] New vector logo and launcher icon, with no old app-brand assets left in use.
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
