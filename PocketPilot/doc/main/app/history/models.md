# History Data Models

> Serializable models for session persistence and conversion utilities.
> -> See: [overview](overview.md) for architecture.

## SessionRecord

> See: `history/model/SessionRecord.kt`

```kotlin
@Serializable
data class SessionRecord(
    val sessionId: String, val startTime: Long, val lastUpdated: Long,
    val messages: List<MessageRecord>,
    val screenStates: List<ScreenStateRecord> = emptyList(),
    val summary: String? = null,
    val metadata: SessionMetadata = SessionMetadata()
)

@Serializable
data class SessionMetadata(
    val appVersion: String? = null, val model: String? = null,
    val traceRunId: String? = null, val turnCount: Int = 0,
    val completedNormally: Boolean = false
)
```

## MessageRecord

> See: `history/model/MessageRecord.kt`

```kotlin
@Serializable
sealed interface MessageRecord {
    val id: String; val timestamp: Long
    data class User(id, timestamp, text: String) : MessageRecord
    data class Agent(id, timestamp, contentBlocks: List<ContentBlockRecord>, isComplete: Boolean) : MessageRecord
}

@Serializable
sealed interface ContentBlockRecord {
    data class Text(val text: String, val turnId: String? = null) : ContentBlockRecord
    data class FinalText(val text: String) : ContentBlockRecord
    data class Reasoning(val text: String, val turnId: String? = null) : ContentBlockRecord
    data class Action(id, toolName, description, state, resultSummary?, expandedContent?) : ContentBlockRecord
}
```

Action `state` values: `"proposed"`, `"executing"`, `"success"`, `"failed"`, `"skipped"`.

Live chat and recording share stream accumulation in `MessageContent.kt`. Answer and reasoning chunks merge independently by model turn, even when a server interleaves them. Tool actions separate trace segments. A nonblank completion replaces the current answer stream with canonical `FinalText`, preserving earlier narration and reasoning. Stopped and failed partial answers are not promoted to a final answer.

History loads the recorded blocks directly. There is no migration of old captions, fragmented streams, or plain-text final answers.

Completed assistant text and expanded reasoning use the Compose Markdown renderer. Parsing runs on `Dispatchers.Default`, text remains selectable, and streaming text retains its cursor until completion. The image transformer is explicitly disabled and no image-loading module is included. Rendering a model response does not fetch its embedded images. Raw HTML is not hosted in a WebView.

## ScreenStateRecord

> See: `history/model/ScreenStateRecord.kt`

Captures screen state metadata per turn: `id`, `timestamp`, `turnId`, `turnNumber`, `phase` (`PRE_TURN`/`POST_ACTION`), `elementCount`, `packageName`, `activityName`, raw/sanitized a11y tree paths, `screenshotPath`, `traceRunId`.

## SessionInfo

> See: `history/model/SessionInfo.kt`

Lightweight summary for session list UI (avoids loading full content): `id`, `fileName`, `startTime`, `lastUpdated`, `messageCount`, `displayTitle` (truncated to 50 chars), `firstUserMessage`, `isActive`.

## Converters

**HistoryItemConverter** (`history/model/HistoryItemConverter.kt`): Bidirectional `ResponseItem` ↔ `PersistedHistoryItem` conversion. `resolveMessageKind()` handles legacy checkpoint migration (including the historical `COMPRESSION_DIGEST` → `COMPACTION_SUMMARY` rename).

**MessageConverter** (`history/model/MessageConverter.kt`): Bidirectional `ChatMessage` ↔ `MessageRecord` conversion for UI layer.
