# Persistence Layer

> SessionHistoryManager, SessionRecordingService, and SessionStorage.
> -> See: [overview](overview.md) for architecture.

## SessionHistoryManager

> See: `history/SessionHistoryManager.kt`

High-level API coordinating between `SessionStorage` and `SessionRecordingService`.

Key operations: `listSessions()`, `loadSession(sessionId)`, `deleteSession(sessionId)`, `startNewSession()`, `resumeSession()`, `clearHistory()`.

- **Session info caching**: `HashMap<String, CachedSessionInfo>` protected by a `Mutex`, with file modification time checks before reuse.
- **Session lookup**: `extractSessionIdFromFileName()` for exact matching (avoids substring collisions with UUID-based IDs).
- **Active session tracking**: Two `SessionRecordingService` instances exist — one in `SessionHistoryManager` (sidebar listing) and a per-session one in `SessionServices` (records events). `externalActiveSessionId` bridges this gap. Set by `MainActivity` at session lifecycle boundaries.

## SessionRecordingService

> See: `history/SessionRecordingService.kt`

Real-time bridge between `AgentEvent` stream and persisted `SessionRecord`.

Key operations: `initializeNewSession()`, `resumeSession()`, `recordUserMessage()`, `startAgentMessage()`, `appendTextDelta()`, `recordAction()`, `updateActionState()`, `recordScreenState()`, `completeAgentMessage()`, `completeSession()`, `clearSessionAndAwait()`.

Key behaviors:

- **Debounced saves**: 500ms delay (`SAVE_DEBOUNCE_MS`) to avoid excessive I/O
- **Agent message buffering**: `AgentMessageBuffer` accumulates streaming text + interleaved actions
- **Immediate save** on session completion
- **Clear barrier**: `clearSessionAndAwait()` cancels pending saves and takes the write mutex before discarding recording state. An already-running forced save finishes before deletion begins.
- **Screen state recording**: Normalizes paths, captures `traceRunId` for replay/debug artifact correlation

## AgentMessageBuffer

> See: `history/AgentMessageBuffer.kt`

Buffers a streaming agent message with interleaved text and action blocks. `appendText(delta)` accumulates in `StringBuilder`; `recordAction(action)` finalizes current text block and adds action block. `buildPartialSnapshot()` for incremental saves; `finalizeSnapshot()` for final output.

## SessionRecordMessageMerger

> See: `history/SessionRecordMessageMerger.kt`

`mergeAgentSnapshot()` updates or inserts an agent message snapshot into a `SessionRecord`, returning a new record with updated `lastUpdated`.

## SessionStorage

> See: `history/storage/SessionStorage.kt`

Low-level file I/O. Key operations: `writeSession()`, `readSession()`, `writeSnapshot()`, `readSnapshot()`, `listSessionFiles()`, `deleteSession()`, `deleteSessionPair()`, `deleteAllSessions()`.

- **Storage location**: `/data/data/{package}/files/sessions/`
- **Session files**: `session-{yyyy-MM-ddTHH-mm-ss}-{uuid}.json`
- **Context files**: `context-{yyyy-MM-ddTHH-mm-ss}-{uuid}.json` (checkpoint snapshots)
- **JSON config**: pretty print, ignore unknown keys, encode defaults
- All I/O on `Dispatchers.IO`

## Deletion ownership

`MainActivity` serializes drawer deletion and Settings data controls. A progress dialog blocks Main input, and the service temporarily hides overlay controls. Confirmation explains when a task will stop.

Deleting one chat shuts down runtime owners using that chat, clears its selected/reload state and retained floating result, waits for its recording writes, then calls `SessionHistoryManager.deleteSession()`. Other chats remain available. `clearHistory()` follows the same shutdown and write-barrier ordering for all current owners, clears Main and floating drafts/results, and deletes the sessions directory through `SessionStorage`.

Clear traces shuts down active work and closes trace writers before deleting both external `inspection-trace` and `debug-output` directories. It preserves chat files, resume context, and displayed results. Clearing history does not delete these separate trace directories.
