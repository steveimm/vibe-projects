package id.steveimm.pocketpilot.qa

import id.steveimm.pocketpilot.ui.chat.components.ChatHeader
import id.steveimm.pocketpilot.ui.theme.PocketPilotTheme
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ChatHeaderTest {

    @get:Rule val compose = createComposeRule()

    @Test fun new_chat_button_hidden_when_showNewChatButton_false() {
        compose.setContent {
            PocketPilotTheme {
                ChatHeader(
                    onMenuClick = {},
                    onNewChatClick = {},
                    showNewChatButton = false
                )
            }
        }

        compose.onAllNodesWithContentDescription("New conversation").assertCountEquals(0)
    }

    @Test fun new_chat_button_visible_and_fires_callback_when_enabled() {
        var clicked = false
        compose.setContent {
            PocketPilotTheme {
                ChatHeader(
                    onMenuClick = {},
                    onNewChatClick = { clicked = true },
                    showNewChatButton = true
                )
            }
        }

        compose.onNodeWithContentDescription("New conversation").performClick()
        assertTrue("onNewChatClick was not invoked", clicked)
    }
}
