package id.steveimm.pocketpilot.agent.cognition.prompt

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.history.MessageKind
import id.steveimm.pocketpilot.history.ResponseItem
import id.steveimm.pocketpilot.model.ScreenImage
import id.steveimm.pocketpilot.model.ScreenImageSource
import id.steveimm.pocketpilot.model.ScreenSnapshot
import org.junit.Test

class PromptBuilderTest {
    @Test
    fun `screenshot is attached without model capability metadata`() {
        val image = ScreenImage(460, 1024, "image/jpeg", byteArrayOf(1, 2), ScreenImageSource.ACCESSIBILITY_SCREENSHOT)
        val observation = TurnObservation.capture(ScreenSnapshot(1, emptyList(), image), "com.android.settings")
        val message = PromptBuilder(HistoryManager()).buildInputItems(observation).single().asEasyInputMessage()
        val contents = message.content().asResponseInputMessageContentList()
        assertThat(contents[1].asInputImage().imageUrl().get()).startsWith("data:image/jpeg;base64,")
        assertThat(contents[0].asInputText().text()).contains("0–1000")
        assertThat(contents[0].asInputText().text()).contains("com.android.settings")
    }

    @Test
    fun `missing screenshot is explicit instead of suggesting blind actions`() {
        val observation = TurnObservation.capture(ScreenSnapshot(1, emptyList()))
        val text = PromptBuilder(HistoryManager()).buildObservationText(observation, emptyList())
        assertThat(text).contains("Screenshot unavailable")
    }

    @Test
    fun `compacted history remains identifiable as earlier context`() {
        val history = HistoryManager().apply {
            addItem(ResponseItem.Message(MessageKind.COMPACTION_SUMMARY, "Settings was opened earlier."))
        }
        val items = PromptBuilder(history).buildInputItems(TurnObservation(null, "Screenshot unavailable"))
        assertThat(items[0].asEasyInputMessage().content().asTextInput()).startsWith("[Context checkpoint from earlier work")
    }
}
