package id.steveimm.pocketpilot.qa

import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.capsule.NavAction
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleContext
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CapsuleLifecycleTest {

    @get:Rule val compose = createComposeRule()

    // K12
    @Test fun error_overlay_can_be_closed() {
        var dismissed = false
        compose.setContent {
            TestCapsule(
                mode = CapsuleMode.Error("Something broke"),
                context = CapsuleContext.SCREEN_VIEWING,
                onNavigate = { if (it == NavAction.CLOSE_OVERLAY) dismissed = true },
            )
        }

        compose.onNodeWithText("Something broke").assertExists()
        compose.onNodeWithContentDescription("Close overlay").performClick()
        assertTrue("Close did not dispatch dismissal", dismissed)
    }

    // K13 — isStopPending replaces Stop with disabled "Stopping..."
    @Test fun is_stop_pending_disables_stop_button() {
        compose.setContent {
            TestCapsule(
                mode = CapsuleMode.Running(thought = "Working"),
                isStopPending = true,
            )
        }

        compose.onNodeWithText("Stopping...").assertExists().assertIsNotEnabled()
        compose.onAllNodesWithText("Stop").assertCountEquals(0)
    }

    @Test fun stop_button_enabled_when_not_stop_pending() {
        compose.setContent {
            TestCapsule(
                mode = CapsuleMode.Running(thought = "Working"),
                isStopPending = false,
            )
        }
        compose.onNodeWithText("Stop").assertIsEnabled()
    }

    // K14
    @Test fun navigation_buttons_fire_correct_nav_action() {
        val fired = mutableListOf<NavAction>()
        compose.setContent {
            TestCapsule(
                mode = CapsuleMode.Running(thought = "Working"),
                context = CapsuleContext.BACKGROUND,
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                onNavigate = { fired += it },
            )
        }

        compose.onNodeWithContentDescription("Stop and close").performClick()
        compose.onNodeWithContentDescription("Open PocketPilot").performClick()
        compose.onNodeWithContentDescription("Open viewer").performClick()

        assertEquals(
            listOf(NavAction.CLOSE_OVERLAY, NavAction.OPEN_APP, NavAction.OPEN_VIEWER),
            fired,
        )
    }
}
