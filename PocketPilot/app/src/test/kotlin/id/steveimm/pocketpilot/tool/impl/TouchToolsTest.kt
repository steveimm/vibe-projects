package id.steveimm.pocketpilot.tool.impl

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.model.ScreenImage
import id.steveimm.pocketpilot.model.ScreenImageSource
import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.platform.ActionResult
import id.steveimm.pocketpilot.platform.AndroidPlatform
import id.steveimm.pocketpilot.platform.DisplayInfo
import id.steveimm.pocketpilot.platform.UIAction
import id.steveimm.pocketpilot.tool.*
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.json.JSONObject
import org.junit.Test

class TouchToolsTest {
    @Test
    fun `same normalized point reaches same device location for resized screenshots`() = runTest {
        for ((width, height) in listOf(460 to 1024, 1080 to 2400)) {
            val context = context(width, height)
            val result = TouchTool("tap").createInvocation(JSONObject("""{"point":[500,250]}""")).execute(context)
            assertThat(result).isInstanceOf(ToolExecutionResult.Success::class.java)
            coVerify(exactly = 1) { context.platform.performAction(UIAction.TapAt(540, 600)) }
        }
    }

    @Test
    fun `edge coordinates stay inside display and swipe keeps its endpoints`() = runTest {
        val context = context(460, 1024)
        TouchTool("swipe").createInvocation(JSONObject("""{"start":[0,1000],"end":[1000,0]}"""))
            .execute(context)
        coVerify { context.platform.performAction(UIAction.Swipe(0, 2399, 1079, 0, 400)) }
    }

    @Test
    fun `missing screenshots or changed orientation never dispatch a gesture`() = runTest {
        for (context in listOf(context(null, null), context(1024, 460))) {
            val result = TouchTool("tap").createInvocation(JSONObject("""{"point":[500,500]}""")).execute(context)
            assertThat(result).isInstanceOf(ToolExecutionResult.Failure::class.java)
            coVerify(exactly = 0) { context.platform.performAction(any()) }
        }
    }

    @Test
    fun `ambiguous unknown and invalid coordinates are rejected`() {
        val tool = TouchTool("tap")
        for (args in listOf("""{"point":["500",500]}""", """{"point":[500.5,500]}""", """{"point":[-1,500]}""",
                            """{"point":[1001,500]}""", """{"point":[500]}""", """{"point":[1,2,3]}""",
                            """{"point":[500,500],"element_index":2}""", """{"x":[500,500]}""")) {
            assertThat(tool.validate(JSONObject(args))).isInstanceOf(ValidationResult.Invalid::class.java)
        }
    }

    @Test
    fun `validation reports every malformed point component together`() {
        val result = TouchTool("swipe").validate(JSONObject("""{"start":["500",1100],"end":[-1]}""")) as ValidationResult.Invalid
        assertThat(result.errors).containsExactly("start[0] must be integer (received string)", "start[1] must be <= 1000",
            "end must contain 2 items", "end[0] must be >= 0")
    }

    @Test
    fun `typing replaces focused field and empty text clears it`() = runTest {
        val context = context(460, 1024)
        for (text in listOf("PocketPilot QA Contact", "")) {
            TypeTextTool().createInvocation(JSONObject().put("text", text)).execute(context)
            coVerify { context.platform.performAction(UIAction.SetTextOnFocused(text, clear = true)) }
        }
    }

    @Test
    fun `typing without a screen observation never changes a field`() = runTest {
        val context = context(null, null)
        val result = TypeTextTool().createInvocation(JSONObject().put("text", "example")).execute(context)
        assertThat(result).isInstanceOf(ToolExecutionResult.Failure::class.java)
        coVerify(exactly = 0) { context.platform.performAction(any()) }
    }

    private fun context(width: Int?, height: Int?): ToolExecutionContext {
        val image = if (width != null && height != null) ScreenImage(width, height, "image/jpeg", byteArrayOf(1),
            ScreenImageSource.ACCESSIBILITY_SCREENSHOT) else null
        val snapshot = ScreenSnapshot(1, emptyList(), image)
        val platform = mockk<AndroidPlatform>()
        every { platform.getDisplayInfo() } returns DisplayInfo(1080, 2400, 2f)
        every { platform.getCurrentPackageName() } returns "com.android.settings"
        coEvery { platform.performAction(any()) } returns ActionResult.Success()
        coEvery { platform.captureScreen() } returns snapshot
        return object : ToolExecutionContext {
            override val platform = platform
            override val currentSnapshot = snapshot
            override fun isCancelled() = false
        }
    }
}
