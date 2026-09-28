package id.steveimm.pocketpilot.debug

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.model.Bounds
import id.steveimm.pocketpilot.model.PerceptionElement
import id.steveimm.pocketpilot.model.Point
import id.steveimm.pocketpilot.model.ScreenSnapshot
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class DebugActionArtifactsTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `reset removes stale artifacts and completion markers only from the selected run directory`() {
        val directory = temporaryFolder.newFolder("action-debug", "latest")
        File(directory, "pre_tree.json").writeText("old tree")
        File(directory, "result.json").writeText("old result")
        File(directory, ".done").createNewFile()
        File(directory, "nested").mkdir()
        File(directory, "nested/old.txt").writeText("old nested artifact")
        val sibling = temporaryFolder.newFile("unrelated.txt").apply { writeText("keep") }

        DebugActionArtifacts(directory, "test").reset()

        assertThat(directory.isDirectory).isTrue()
        assertThat(directory.listFiles()).isEmpty()
        assertThat(sibling.readText()).isEqualTo("keep")
    }

    @Test
    fun `both tree files preserve the debug snapshot JSON schema and text`() {
        val directory = File(temporaryFolder.root, "mobile-action-debug/latest")
        val artifacts = DebugActionArtifacts(directory, "test").reset()
        val snapshot = ScreenSnapshot(
            timestamp = 123L,
            elements = listOf(
                PerceptionElement(
                    index = 0,
                    text = "  네이버 지도\nSearch  ",
                    resourceId = "maps:id/search",
                    className = "EditText",
                    description = "Map search",
                    isClickable = true,
                    isEditable = true,
                    isScrollable = false,
                    isEnabled = false,
                    isFocused = true,
                    isLongClickable = false,
                    bounds = Bounds(0, 0, 200, 80),
                    center = Point(100, 40),
                ),
            ),
        )

        artifacts.writeTree("pre_tree.json", snapshot)
        artifacts.writeTree("post_tree.json", snapshot)

        val preTree = File(directory, "pre_tree.json").readText()
        assertThat(File(directory, "post_tree.json").readText()).isEqualTo(preTree)
        val elements = JSONArray(preTree)
        assertThat(elements.length()).isEqualTo(1)
        val element = elements.getJSONObject(0)
        assertThat(element.getInt("index")).isEqualTo(0)
        assertThat(element.getString("text")).isEqualTo("  네이버 지도\nSearch  ")
        assertThat(element.getString("desc")).isEqualTo("Map search")
        assertThat(element.getString("class")).isEqualTo("EditText")
        assertThat(element.getBoolean("editable")).isTrue()
        assertThat(element.getBoolean("enabled")).isFalse()
        assertThat(element.getJSONArray("center").toString()).isEqualTo("[100,40]")
        assertThat(File(directory, ".done").exists()).isFalse()
    }

    @Test
    fun `finish preserves each runner's result schema and writes the completion marker`() {
        val results = listOf(
            JSONObject("""{"version":1,"layer":"platform","action":"tap","action_accepted":{"status":"success"}}"""),
            JSONObject("""{"version":1,"tool":"mobile_action","phase":"execute","result":{"status":"success"}}"""),
        )
        results.forEachIndexed { index, result ->
            val directory = temporaryFolder.newFolder("run-$index")
            val artifacts = DebugActionArtifacts(directory, "test").reset()

            artifacts.finish(result)

            assertThat(File(directory, "result.json").readText()).isEqualTo(result.toString(2))
            assertThat(File(directory, ".done").isFile).isTrue()
        }
    }

    @Test
    fun `a failed result write does not publish a completion marker`() {
        val directory = temporaryFolder.newFolder("failed-run")
        val artifacts = DebugActionArtifacts(directory, "test").reset()
        File(directory, "result.json").mkdir()

        artifacts.finish(JSONObject().put("status", "success"))

        assertThat(File(directory, ".done").exists()).isFalse()
    }
}
