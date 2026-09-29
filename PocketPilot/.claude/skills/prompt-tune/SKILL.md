---
name: prompt-tune
description: Apply evidence-backed changes to the core prompt or tool descriptions after diagnosing a model run.
---

# Prompt Tune

Read `../autotune/references/tuning_principles.md` before changing model instructions.

Use runtime traces to identify the failure first. Keep changes general across apps and task variants, with the smallest instruction that addresses observed behavior.

## Ownership

- The core system prompt owns behavior across tools, observation use, and task termination.
- Tool descriptions own parameter semantics, coordinate units, valid combinations, and tool-local limitations.
- Runtime warnings describe observed facts. They do not prescribe speculative strategies.

Read the target file before editing. Reuse existing helpers, avoid duplicate instructions, and avoid app-specific task recipes or hardcoded eval answers. PocketPilot has no runtime app-skill or agent-skill loader.

## Validation

Run relevant release tests and verify the change with the emulator and configured local model. Inspect both the model's actual inputs/outputs and the resulting screen. Do not treat a successful tool return as proof that the task succeeded. Build only the APK variant required by the user.

Primary sources:

- `agent/definition/DefaultAgentDef.kt`
- `agent/cognition/prompt/PromptBuilder.kt`
- `agent/cognition/prompt/TurnObservation.kt`
- `tool/impl/`

Use `/cog-tune` for diagnosis and `/action-debug` when the failure is in execution rather than model output.
