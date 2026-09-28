package id.steveimm.pocketpilot.session

import android.content.Context
import android.content.res.AssetManager
import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.auth.AuthCredential
import id.steveimm.pocketpilot.auth.AuthStore
import id.steveimm.pocketpilot.auth.FakeSharedPreferences
import id.steveimm.pocketpilot.auth.MissingCredential
import id.steveimm.pocketpilot.llm.ChatCompletionClient
import id.steveimm.pocketpilot.llm.LLMProvider
import id.steveimm.pocketpilot.llm.ModelCatalogRepository
import id.steveimm.pocketpilot.llm.ModelCatalogRepositoryHolder
import id.steveimm.pocketpilot.protocol.LLMBackendType
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import id.steveimm.pocketpilot.test.FakeAndroidPlatform
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.trace.NoopTraceRecorder
import io.mockk.every
import io.mockk.mockk
import java.io.ByteArrayInputStream
import java.io.File
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class SessionServicesProviderRoutingTest {

  @get:Rule
  val tempDir = TemporaryFolder()

  @After
  fun tearDown() {
    ModelCatalogRepositoryHolder.resetForTest()
  }

  @Test
  fun `openrouter model works without openai key`() {
    val context = contextWithCatalog()
    installFixtureCatalogRepo(context)
    val authStore = AuthStore(context, prefsProvider = { FakeSharedPreferences() })
    runBlocking {
      authStore.set(LLMProvider.OPENROUTER, AuthCredential.ApiKey("sk-or-test"))
    }
    val config =
            SessionConfig(
                    llm = SessionLlmConfig(backendType = LLMBackendType.OPENAI),
                    mainModel = "glm-4.7"
            )
    val services =
            SessionServices.create(
                    config = config,
                    platform = FakeAndroidPlatform(),
                    authStore = authStore,
                    context = context,
                    scope =
                            kotlinx.coroutines.CoroutineScope(
                                    kotlinx.coroutines.Dispatchers.Unconfined
                            ),
                    traceRecorder = NoopTraceRecorder,
                    appClassifier = AppClassifier(emptyMap())
            )

    assertThat(services.llmClient).isInstanceOf(ChatCompletionClient::class.java)
  }

  @Test
  fun `main model requires its provider credential`() {
    val context = contextWithCatalog()
    installFixtureCatalogRepo(context)
    val authStore = AuthStore(context, prefsProvider = { FakeSharedPreferences() })
    runBlocking {
      authStore.set(LLMProvider.OPENAI_API, AuthCredential.ApiKey("sk-openai-test"))
    }
    val config =
            SessionConfig(
                    llm = SessionLlmConfig(backendType = LLMBackendType.OPENAI),
                    mainModel = "other-model"
            )

    val error =
            assertThrows(MissingCredential::class.java) {
              SessionServices.create(
                      config = config,
                      platform = FakeAndroidPlatform(),
                      authStore = authStore,
                      context = context,
                      scope =
                              kotlinx.coroutines.CoroutineScope(
                                      kotlinx.coroutines.Dispatchers.Unconfined
                              ),
                      traceRecorder = NoopTraceRecorder,
                      appClassifier = AppClassifier(emptyMap())
              )
            }
    assertThat(error.provider).isEqualTo(LLMProvider.OTHER)
  }

  private fun contextWithCatalog(): Context {
    val context = mockk<Context>(relaxed = true)
    val assets = mockk<AssetManager>()
    every { context.assets } returns assets
    every { context.applicationContext } returns context
    every { context.filesDir } returns tempDir.newFolder("files")
    every { assets.list(any<String>()) } answers {
      val file = File("src/main/assets", firstArg<String>())
      if (file.isDirectory) file.list().orEmpty() else emptyArray()
    }
    every { assets.open(any<String>()) } answers {
      when (val path = firstArg<String>()) {
        "llm_models.json" -> ByteArrayInputStream(CATALOG_JSON.toByteArray())
        "security/app_tiers.json" -> ByteArrayInputStream(APP_TIERS_JSON.toByteArray())
        else -> File("src/main/assets", path).inputStream()
      }
    }
    return context
  }

  /**
   * Install a fixture [ModelCatalogRepository] backed by [context]'s mocked assets so
   * `SessionServices.create` resolves models from CATALOG_JSON rather than the real seed.
   */
  private fun installFixtureCatalogRepo(context: Context) {
    val settingsStore = mockk<id.steveimm.pocketpilot.app.AppSettingsStore>(relaxed = true)
    every { settingsStore.load() } returns id.steveimm.pocketpilot.app.AppSettings(
        selectedModel = id.steveimm.pocketpilot.app.AppSettingsStore.DEFAULT_MODEL,
        debugMode = false,
        perceptionMode = id.steveimm.pocketpilot.app.AppSettingsStore.DEFAULT_PERCEPTION_MODE,
        llmBackend = id.steveimm.pocketpilot.app.AppSettingsStore.DEFAULT_LLM_BACKEND,
        localModel = id.steveimm.pocketpilot.ui.settings.AVAILABLE_LOCAL_MODELS.first(),
        platformMode = id.steveimm.pocketpilot.app.AppSettingsStore.DEFAULT_PLATFORM_MODE,
        traceEnabled = false,
        browserScriptEnabled = false,
        termuxShellEnabled = false,
        openaiBaseUrl = "",
        otherBaseUrl = "",
        otherModelId = "",
        approvalMode = id.steveimm.pocketpilot.app.AppSettingsStore.DEFAULT_APPROVAL_MODE,
    )
    val repo = ModelCatalogRepository(
        context = context,
        settingsStore = settingsStore,
        discoveryCache = mockk(relaxed = true),
    )
    ModelCatalogRepositoryHolder.setForTest(repo)
  }

  companion object {
    private val CATALOG_JSON =
            """
        {
          "gpt-5.2": {
            "display_name": "GPT-5.2",
            "provider":"OPENAI_API",
            "api": "response",
            "model_id": "gpt-5.2"
          },
          "glm-4.7": {
            "display_name": "GLM-4.7",
            "provider": "OPENROUTER",
            "api": "chat",
            "model_id": "z-ai/glm-4.7"
          },
          "other-model": {
            "display_name": "Custom Other Model",
            "provider": "OTHER",
            "api": "chat",
            "model_id": "user/custom",
            "base_url": "https://example.invalid/v1"
          }
        }
        """.trimIndent()

    private val APP_TIERS_JSON = """{"apps":{}}"""
  }
}
