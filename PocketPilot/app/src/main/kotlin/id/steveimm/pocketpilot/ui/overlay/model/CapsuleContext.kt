package id.steveimm.pocketpilot.ui.overlay.model

/** CapsuleContext — where the Smart Capsule is currently displayed. */
enum class CapsuleContext {
    /** User is in the PocketPilot main app. Capsule is embedded via Compose. */
    MAIN_APP,

    /** User is viewing the agent's screen (A11y overlay or VD viewer). Capsule is a system overlay. */
    SCREEN_VIEWING,

    /** VD mode, user on their own screen. Status island visible, capsule hidden. */
    BACKGROUND
}
