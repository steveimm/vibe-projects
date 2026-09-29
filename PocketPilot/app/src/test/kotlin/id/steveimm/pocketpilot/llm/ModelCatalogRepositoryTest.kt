package id.steveimm.pocketpilot.llm

import android.content.Context
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class ModelCatalogRepositoryTest {
    @get:Rule val temporary = TemporaryFolder()
    private fun cache(): ModelDiscoveryCache = ModelDiscoveryCache(mockk<Context> { every { filesDir } returns temporary.root })

    @Test
    fun `manual model ID works without discovery or a bundled model catalog`() {
        val repository = ModelCatalogRepository(cache())
        val entry = repository.forServer("http://local:8000/v1", "my-custom-model").resolve("my-custom-model")
        assertThat(entry.modelId).isEqualTo("my-custom-model")
    }

    @Test
    fun `discovery cache is scoped to the selected server and preserves server metadata`() = runTest {
        val cache = cache()
        val repository = ModelCatalogRepository(cache, discover = { _, key ->
            assertThat(key).isEmpty()
            listOf(ModelEntry("small-model", contextWindow = 4096))
        })
        repository.refresh("http://server-a:8000/v1")
        val a = repository.forServer("http://server-a:8000/v1", "small-model")
        assertThat(a.resolve("small-model").contextWindow).isEqualTo(4096)
        val b = repository.forServer("http://server-b:8000/v1", "manual-b")
        assertThat(b.names()).containsExactly("manual-b")
        assertThat(ModelCatalogRepository(cache()).forServer("http://server-a:8000/v1", "small-model").names())
            .containsExactly("small-model")
    }

    @Test
    fun `failed discovery retains the last successful model list`() = runTest {
        var fail = false
        val repository = ModelCatalogRepository(cache(), discover = { _, _ ->
            if (fail) error("offline")
            listOf(ModelEntry("local-model"))
        })
        repository.refresh("http://local:8000/v1")
        fail = true
        assertThat(runCatching { repository.refresh("http://local:8000/v1") }.isFailure).isTrue()
        assertThat(repository.forServer("http://local:8000/v1", "").names()).containsExactly("local-model")
    }
}
