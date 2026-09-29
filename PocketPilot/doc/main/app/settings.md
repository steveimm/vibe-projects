# Settings

Settings contains Model server, Agent Behavior, App Access, System & Debug, and Open Source Licenses.

## Model server

Enter an HTTP(S) API base URL or full Chat Completions URL, an exact model ID, and an optional key. Model discovery is optional. Keys are encrypted and scoped to the normalized endpoint. There are no built-in cloud accounts or provider tabs.

## Agent behavior

Perception options control the screen data provided to the model. Display options choose accessibility or the Shizuku-backed virtual display. Approval mode controls whether non-blocked app actions ask for approval.

The only optional additional tool is Termux shell. Its settings show installation, permission, and bridge readiness. Enabling a preference alone does not expose an unavailable tool.

## App access

Search installed apps and choose Allow, Ask, or Reject. Bundled blocked apps expose only Reject and cannot be unblocked with an override. Auto-approve does not override blocked apps. This page contains no memory or skill editors.

## System and debugging

Permission controls open the relevant Android settings. Debug logging and session traces are opt-in. Trace files include screen observations, model inputs/outputs, native reasoning, tool calls, and results.

`AppSettingsStore` persists user configuration. `AppSettingsState` provides the live UI state. Model server settings are saved as a URL/model pair; each running session captures its own server configuration.
