package id.steveimm.pocketpilot.app

internal class BubbleDragTakeover {
    private enum class State { IDLE, DRAGGING, PAUSED, RELEASED }
    private var state = State.IDLE

    fun begin(isRunning: Boolean): Boolean {
        if (state == State.RELEASED) { state = State.DRAGGING; return false }
        if (!isRunning || state != State.IDLE) return false
        state = State.DRAGGING
        return true
    }

    fun finish(): Boolean = when (state) {
        State.DRAGGING -> { state = State.RELEASED; false }
        State.PAUSED -> { state = State.IDLE; true }
        else -> false
    }

    fun onPaused(): Boolean = when (state) {
        State.DRAGGING -> { state = State.PAUSED; false }
        State.RELEASED -> { state = State.IDLE; true }
        else -> false
    }

    fun cancel() { state = State.IDLE }
}
