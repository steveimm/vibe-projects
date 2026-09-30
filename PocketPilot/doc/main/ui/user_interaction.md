# UI interaction

## Chat

The header contains PocketPilot's navigation mark, the configured model, history, and a new-chat action. Empty chats offer compact suggestions that fill the composer without sending. There is no second logo, hero section, or instructional footer.

During a task, the control panel provides progress, Takeover, Stop, and optional input. Activity expands once to show native model reasoning and tool actions. The answer remains visible independently. Scrolling upward or opening activity stops automatic following. Latest returns to the newest content.

Stopping retains partial output and labels it Stopped. Errors remain in the conversation, and the composer becomes available for another request. New chat resets the draft and startup feedback.

## History and settings

The drawer lists saved chats and opens Settings. Android Back closes the drawer. Opening a chat restores its recorded messages. Deleting a chat requires confirmation. Storage failures are shown to the user.

Settings keeps a back stack. App access opened from Automation returns to Automation before returning to Settings. Back and Close have distinct roles: Back returns one page, while Close exits Settings.

The model-server page accepts an HTTP(S) API base URL or full Chat Completions URL, an optional key, and a model ID. Test connection checks the current unsaved endpoint/key. It reports reachability, authentication failures, HTTP errors, or network failures. Advertised models become available from the Model ID selector. Manual entry remains available. Save applies the configuration to new chats.

## Setup

Setup covers accessibility, floating controls, optional background permission, model-server configuration, and an optional demo. Already-granted permissions can be skipped automatically. Back returns to the preceding step. Saving a server does not complete unfinished setup by itself.

The demo asks the model to open Android Settings and checks the observed package before reporting success. A demo failure can be retried or skipped.

## Floating controls

The persistent bubble remains outside Main before, during, and after tasks. Drag it to reposition it. Release docks it to an edge. Tap toggles the panel. Drafts survive minimizing and reopening the panel.

Questions expose a reply field. User-action requests expose Done. App approvals offer persistent approval, session approval, or rejection. A stopped task stays distinguishable from a finished task. The panel always offers Open chat and Close. Close dismisses floating controls and stops active work. Touch protection is optional and off by default. Action indicators can be disabled independently.

See [overlay behavior](overlay.md) and [capsule architecture](capsule/architecture.md) for implementation details.
