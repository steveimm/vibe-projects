# Data Schemas

Catalog of core in-memory and persisted schemas in PocketPilot, plus redundancy / inconsistency findings worth tracking. Sourced from code on 2026-04-18.

## 1. AppSettingsState — local model

File: `app/src/main/kotlin/id/steveimm/pocketpilot/app/AppSettingsState.kt`

A single non-null `localModel: LocalModelOption` identifies the on-device model. `LocalModelOption` (`ui/settings/SettingsModels.kt:27`) bundles `id`, `modelSlug`, `quantizationSlug`, plus display fields. `AppSettingsStore` persists only `id` and rehydrates by lookup in the static `AVAILABLE_LOCAL_MODELS` table; if the persisted id is unknown, `DEFAULT_LOCAL_MODEL` is returned. The catalog is the single source of truth — slug/quant are never persisted independently.

## 2. SessionRuntimeSnapshot — scratchpad dual format

File: `app/src/main/kotlin/id/steveimm/pocketpilot/history/model/SessionRuntimeSnapshot.kt`

```kotlin
val scratchpadJson: String = "{}"
val scratchpad: Map<String, String>? = null  // legacy
```

Old checkpoints serialized scratchpad as a typed map; new writes use a freeform JSON string. The legacy field is retained only for backward-compatible deserialization. Per the doc-comment, **new writes never set `scratchpad`** — it should always be `null` going forward.

**Redundancy:** dual format. Once historical checkpoints are no longer needed (or migrated), the legacy `Map<String, String>?` field can be removed.

## 3. ConversationConfigSnapshot — String-typed enums

File: `app/src/main/kotlin/id/steveimm/pocketpilot/history/model/SessionRuntimeSnapshot.kt:60`

```kotlin
data class ConversationConfigSnapshot(
    val mainModel: String,
    val perceptionMode: String,   // backed by free-form string + UI options
    val platformMode: String,     // backed by PlatformMode enum
    val approvalMode: String = "SMART", // backed by ApprovalMode enum
    val serverBaseUrl: String = "", // explicit HTTP(S) model server
    ...
)
```

Several mode/type fields are stored as raw `String` even though strongly-typed enums exist:
- `PlatformMode` — `ACCESSIBILITY`, `VIRTUAL_DISPLAY` (`protocol/SessionConfig.kt:64`)
- `ApprovalMode` — `ALWAYS_ASK`, `AUTO_APPROVE`, `SMART` (`protocol/SessionConfig.kt:88`)

**Redundancy / risk:** the string boundary loses compile-time guarantees. Any typo in a writer or rename of an enum value silently corrupts checkpoints. Round-tripping currently relies on `valueOf` at consumption sites with no central validator.

## 4. OnboardingStepState — three sealed hierarchies

File: `app/src/main/kotlin/id/steveimm/pocketpilot/onboarding/OnboardingState.kt:43`

`OnboardingStepState` is a marker sealed interface with three sealed children, totaling 23 concrete subtypes (description undercounted as 21):

| Hierarchy             | Count | Subtypes                                                                                                |
|-----------------------|-------|---------------------------------------------------------------------------------------------------------|
| `PermissionStepState` | 6     | `Checking`, `Ready`, `OpeningSettings`, `Satisfied`, `Unsatisfied`, `Skipped`                           |
| `DemoStepState`       | 7     | `Ready`, `Preflight`, `Running`, `Success`, `Failure`, `CredentialError`, `Skipped`                     |

Only one is active at a time per the file's comment ("Per-step transient state (one active at a time)"). Hierarchies are disjoint — no shared common state beyond the marker interface — so the marker exists more for grouping than for polymorphism.


## 5. TodoSnapshot — String status parsed via valueOf

File: `app/src/main/kotlin/id/steveimm/pocketpilot/history/model/SessionRuntimeSnapshot.kt:79`

```kotlin
@Serializable
data class TodoSnapshot(
    val description: String,
    val status: String   // serialized form of TodoStatus
)
```

Backed by `TodoStatus` enum (`protocol/TodoModels.kt:14`): `PENDING`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`.

Reload path uses `TodoStatus.valueOf(todo.status)` at:
- `session/AgentSession.kt:173` — wrapped in try/catch falling back to `PENDING`
- `tool/impl/WriteTodosTool.kt:120` (`parseStatus`) — uppercases + trims, returns null on failure

**Redundancy / risk:** same pattern as ConversationConfigSnapshot — String at the persistence boundary, enum at the runtime boundary, `valueOf` glue at every read site. A single `@Serializable` use of `TodoStatus` (kotlinx-serialization handles enum names natively) would eliminate both call sites and the silent fall-through.

## Cross-cutting observation

Patterns 3 and 5 share a root cause: persisted snapshots declare enums as `String` rather than as `@Serializable` enum types. Migrating both to native enum serialization would centralize validation, surface schema drift at deserialization (not at first read), and remove ad-hoc `valueOf` wrappers. Pattern 1 (denormalized model trio) and pattern 2 (legacy scratchpad) are both safe to compact once a checkpoint migration window is acceptable.
