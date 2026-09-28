package id.steveimm.pocketpilot.ui.settings

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.Test

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class SettingsToggleGateTest {
    @Test
    fun `turning off cancels a pending enable without persisting its eventual success`() = runTest {
        val persisted = mutableListOf<Boolean>()
        val release = CompletableDeferred<Unit>()
        val gate = SettingsToggleGate<String>(
            scope = backgroundScope,
            onPersist = { persisted += it },
            gate = {
                release.await()
                null
            },
            ioDispatcher = UnconfinedTestDispatcher(testScheduler),
        )

        gate.setEnabled(true)
        runCurrent()
        assertThat(gate.pending).isTrue()

        gate.setEnabled(false)
        release.complete(Unit)
        runCurrent()

        assertThat(gate.pending).isFalse()
        assertThat(gate.error).isNull()
        assertThat(persisted).containsExactly(false)
    }

    @Test
    fun `an older cancelled attempt cannot clear the pending state of a new attempt`() = runTest {
        val firstRelease = CompletableDeferred<Unit>()
        val secondRelease = CompletableDeferred<Unit>()
        val persisted = mutableListOf<Boolean>()
        var calls = 0
        val gate = SettingsToggleGate<String>(
            scope = backgroundScope,
            onPersist = { persisted += it },
            gate = {
                if (++calls == 1) withContext(NonCancellable) { firstRelease.await() }
                else secondRelease.await()
                null
            },
            ioDispatcher = UnconfinedTestDispatcher(testScheduler),
        )

        gate.setEnabled(true)
        runCurrent()
        gate.setEnabled(false)
        gate.setEnabled(true)
        runCurrent()
        firstRelease.complete(Unit)
        runCurrent()

        assertThat(gate.pending).isTrue()
        assertThat(persisted).containsExactly(false)

        secondRelease.complete(Unit)
        runCurrent()
        assertThat(gate.pending).isFalse()
        assertThat(persisted).containsExactly(false, true).inOrder()
    }

    @Test
    fun `immediately completed permission check clears pending state`() = runTest {
        val persisted = mutableListOf<Boolean>()
        val scope = CoroutineScope(backgroundScope.coroutineContext + Dispatchers.Unconfined)
        val gate = SettingsToggleGate<String>(
            scope = scope,
            onPersist = { persisted += it },
            gate = { null },
            ioDispatcher = Dispatchers.Unconfined,
        )

        gate.setEnabled(true)

        assertThat(gate.pending).isFalse()
        assertThat(persisted).containsExactly(true)
    }
}
