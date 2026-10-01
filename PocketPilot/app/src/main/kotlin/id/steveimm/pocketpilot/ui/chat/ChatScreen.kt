package id.steveimm.pocketpilot.ui.chat

import androidx.compose.foundation.layout.Spacer
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import kotlinx.coroutines.flow.collectLatest
import androidx.activity.compose.BackHandler

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.background
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import id.steveimm.pocketpilot.app.AgentService
import id.steveimm.pocketpilot.history.model.SessionInfo
import id.steveimm.pocketpilot.ui.capsule.CapsuleBinding
import id.steveimm.pocketpilot.ui.capsule.NavAction
import id.steveimm.pocketpilot.ui.capsule.surface.LocalVoiceFeedback
import id.steveimm.pocketpilot.ui.capsule.surface.SmartCapsuleSurface
import id.steveimm.pocketpilot.ui.capsule.surface.VoiceMicDeps
import id.steveimm.pocketpilot.ui.capsule.surface.smartCapsuleHostPadding
import id.steveimm.pocketpilot.ui.capsule.voice.AndroidRecognizerFactory
import id.steveimm.pocketpilot.onboarding.PermissionStateMonitor.PermissionRepairModel
import id.steveimm.pocketpilot.ui.chat.components.ChatHeader
import id.steveimm.pocketpilot.ui.chat.components.EmptyState
import id.steveimm.pocketpilot.ui.chat.components.MessageBubble
import id.steveimm.pocketpilot.ui.chat.model.ChatMessage
import id.steveimm.pocketpilot.ui.navigation.NavigationDrawerContent
import id.steveimm.pocketpilot.ui.onboarding.PermissionRepairCard
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleContext
import id.steveimm.pocketpilot.ui.settings.AlertTone
import id.steveimm.pocketpilot.ui.settings.SettingsAlertCard
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion
import id.steveimm.pocketpilot.ui.theme.pocketPilot
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private data class VoiceFeedbackAlert(
    val id: Long,
    val message: String,
)

/** ChatScreen - Main chat interface composable. */
@Composable
fun ChatScreen(
    viewModel: ChatViewModel,
    capsuleBinding: CapsuleBinding,
    sessions: List<SessionInfo>,
    currentModel: String,
    onOpenSettings: (SettingsDeepLink?) -> Unit,
    onSessionSelect: (SessionInfo) -> Unit,
    onNewSession: () -> Unit,
    onDeleteSession: (SessionInfo) -> Unit,
    onLoadSessions: (onLoaded: () -> Unit) -> Unit,
    onOpenViewer: () -> Unit,
    onOpenApp: (String) -> Unit,
    repairModel: PermissionRepairModel? = null,
    onFixAccessibility: () -> Unit = {},
    onFixOverlay: () -> Unit = {},
    onFixBattery: () -> Unit = {},
    modifier: Modifier = Modifier,
    isVisible: Boolean = true,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHost = remember { SnackbarHostState() }
    LaunchedEffect(uiState.historyError) {
        uiState.historyError?.let {
            snackbarHost.showSnackbar(it)
            viewModel.dismissHistoryError()
        }
    }
    val messages = viewModel.messages
    val pendingInput by viewModel.pendingInput.collectAsStateWithLifecycle()
    val startupError by viewModel.startupError.collectAsStateWithLifecycle()

    val capsuleMode by capsuleBinding.mode.collectAsStateWithLifecycle()
    val capsulePlatformMode by capsuleBinding.platformMode.collectAsStateWithLifecycle()
    val isStopPending by capsuleBinding.isStopPending.collectAsStateWithLifecycle()
    val lastToolCall by capsuleBinding.lastToolCall.collectAsStateWithLifecycle()

    val focusManager = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current
    var inputFocused by remember { mutableStateOf(false) }
    val hideInput: () -> Unit = { focusManager.clearFocus(force = true); keyboard?.hide() }
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val drawerListState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val inputVisible = isVisible && drawerState.currentValue == DrawerValue.Closed && drawerState.targetValue == DrawerValue.Closed
    val questionId = (capsuleMode as? CapsuleMode.WaitingForInput)?.callId
    var autoFocusQuestionId by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(isVisible) {
        if (!isVisible) { autoFocusQuestionId = null; hideInput() }
    }
    LaunchedEffect(questionId) {
        autoFocusQuestionId = questionId.takeIf { inputVisible }
    }

    BackHandler(enabled = drawerState.isOpen) {
        scope.launch { drawerState.close() }
    }

    val ctx = LocalContext.current
    val voiceDeps = remember(ctx) {
        val activity = ctx as? android.app.Activity
        object : VoiceMicDeps {
            override val factory = AndroidRecognizerFactory(ctx.applicationContext)
            override val activity: android.app.Activity? = activity
            override fun isPermissionGranted(): Boolean =
                androidx.core.content.ContextCompat.checkSelfPermission(
                    ctx,
                    android.Manifest.permission.RECORD_AUDIO,
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            override fun requestOverlayPermission() {
                // MAIN_APP path uses the in-process activity launcher; the overlay route is unused
                // here. Fallback safely to the AgentService bridge so misuse is non-fatal.
                AgentService.instance?.requestVoicePermissionViaMainActivity()
            }
        }
    }
    var nextVoiceFeedbackId by remember { mutableStateOf(0L) }
    var voiceFeedback by remember { mutableStateOf<VoiceFeedbackAlert?>(null) }
    val reportVoiceFeedback: (String) -> Unit = { message ->
        nextVoiceFeedbackId += 1
        voiceFeedback = VoiceFeedbackAlert(nextVoiceFeedbackId, message)
    }
    LaunchedEffect(voiceFeedback?.id) {
        val current = voiceFeedback ?: return@LaunchedEffect
        delay(7_000)
        if (voiceFeedback?.id == current.id) {
            voiceFeedback = null
        }
    }

    LaunchedEffect(drawerState.targetValue) {
        if (drawerState.targetValue == DrawerValue.Open) {
            autoFocusQuestionId = null
            hideInput()
        }
    }

    // Load sessions when drawer opens
    LaunchedEffect(drawerState.isOpen) {
        if (drawerState.isOpen) {
            val openingIndex = drawerListState.firstVisibleItemIndex
            val openingOffset = drawerListState.firstVisibleItemScrollOffset
            onLoadSessions {
                if (drawerState.targetValue == DrawerValue.Open && !drawerListState.isScrollInProgress &&
                    drawerListState.firstVisibleItemIndex == openingIndex &&
                    drawerListState.firstVisibleItemScrollOffset == openingOffset
                ) {
                    drawerListState.requestScrollToItem(0)
                }
            }
        }
    }

    ModalNavigationDrawer(
        drawerState = drawerState,
        modifier = modifier.fillMaxSize().then(if (isVisible) Modifier else Modifier.clearAndSetSemantics {}),
        drawerContent = {
            NavigationDrawerContent(
                sessions = sessions,
                listState = drawerListState,
                onSessionSelect = { session ->
                    scope.launch { drawerState.close() }
                    hideInput()
                    onSessionSelect(session)
                },
                onNewSession = {
                    scope.launch { drawerState.close() }
                    hideInput()
                    onNewSession()
                },
                onDeleteSession = onDeleteSession,
                onSettingsClick = {
                    scope.launch { drawerState.close() }
                    hideInput()
                    onOpenSettings(null)
                },
                onClose = {
                    scope.launch { drawerState.close() }
                }
            )
        },
        gesturesEnabled = isVisible
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .pointerInput(focusManager) {
                    awaitEachGesture {
                        awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
                        if (!inputFocused) focusManager.clearFocus()
                    }
                },
        ) {
            Scaffold(
                snackbarHost = { SnackbarHost(snackbarHost) },
                modifier = Modifier.fillMaxSize(),
                contentWindowInsets = WindowInsets(0, 0, 0, 0),
                containerColor = Color.Transparent,
                topBar = {
                    ChatHeader(
                        modifier = Modifier
                            .shadow(MaterialTheme.pocketPilot.elevation.floating, clip = false)
                            .background(MaterialTheme.colorScheme.surface),
                        onMenuClick = {
                            hideInput()
                            scope.launch { drawerState.open() }
                        },
                        onNewChatClick = { hideInput(); onNewSession() },
                        modelName = currentModel,
                        showNewChatButton = messages.isNotEmpty()
                    )
                },
                bottomBar = {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .shadow(MaterialTheme.pocketPilot.elevation.floating, clip = false)
                            .background(MaterialTheme.colorScheme.surface)
                            .imePadding()
                            .navigationBarsPadding()
                            .smartCapsuleHostPadding()
                    ) {
                        if (repairModel != null) {
                            PermissionRepairCard(
                                model = repairModel,
                                onFixAccessibility = { hideInput(); onFixAccessibility() },
                                onFixOverlay = { hideInput(); onFixOverlay() },
                                onFixBattery = { hideInput(); onFixBattery() },
                            )
                        }
                        voiceFeedback?.let { alert ->
                            SettingsAlertCard(
                                message = alert.message,
                                tone = AlertTone.Error,
                                modifier = Modifier.padding(bottom = MaterialTheme.pocketPilot.spacing.sm),
                            )
                        }
                        CompositionLocalProvider(LocalVoiceFeedback provides reportVoiceFeedback) {
                            SmartCapsuleSurface(
                                onInputFocusChanged = { inputFocused = it },
                                mode = when (capsuleMode) {
                                    is CapsuleMode.Done, is CapsuleMode.Error -> CapsuleMode.Hidden
                                    else -> capsuleMode
                                },
                                isStopPending = isStopPending,
                                platformMode = capsulePlatformMode,
                                context = CapsuleContext.MAIN_APP,
                                onSend = viewModel::sendMessage,
                                onSupplement = viewModel::sendSupplement,
                                onTakeover = viewModel::requestTakeover,
                                onResume = viewModel::requestResume,
                                onSupplementAndResume = viewModel::sendSupplementAndResume,
                                onStop = {
                                    if (capsuleBinding.onStopRequested()) {
                                        viewModel.stopTask()
                                    }
                                },
                                onUserResponse = { callId, response ->
                                    forwardUserResponse(capsuleBinding, viewModel::sendUserResponse, callId, response)
                                },
                                onApprovalResponse = { callId, decision, approvalScope, packageName ->
                                    if (capsuleBinding.onApprovalResolved(callId)) {
                                        viewModel.sendApprovalResponse(callId, decision, approvalScope, packageName)
                                    }
                                },
                                onNavigate = { action ->
                                    if (action == NavAction.OPEN_VIEWER) {
                                        hideInput()
                                        onOpenViewer()
                                    }
                                },
                                modifier = Modifier.fillMaxWidth(),
                                inputDraft = if (capsuleMode is CapsuleMode.WaitingForInput) {
                                    capsuleBinding.responseDraft ?: viewModel.inputDraft
                                } else viewModel.inputDraft,
                                inputActive = inputVisible,
                                lastToolCall = lastToolCall,
                                autoFocusInput = inputVisible && questionId != null && questionId == autoFocusQuestionId,
                                pendingInputText = pendingInput.takeIf { inputVisible }.orEmpty(),
                                onPendingInputConsumed = { viewModel.consumePendingInput() },
                                startupError = startupError,
                                onDismissStartupError = { viewModel.dismissStartupError() },
                                onStartupErrorClick = {
                                    hideInput()
                                    onOpenSettings(viewModel.startupErrorDeepLink.value)
                                },
                                voice = voiceDeps,
                            )
                        }
                    }
                }
            ) { paddingValues ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                        .clipToBounds()
                ) {
                    if (messages.isEmpty() && uiState.showEmptyState) {
                        // Empty state
                        EmptyState(
                            onSuggestionClick = viewModel::prepareMessage,
                            modifier = Modifier.fillMaxSize()
                        )
                    } else if (messages.isNotEmpty()) {
                        // Message list
                        MessageList(
                            messages = messages,
                            onOpenApp = { packageName -> hideInput(); onOpenApp(packageName) },
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                }
            }
        }
    }
}

/** MessageList - Scrollable list of chat messages with stick-to-bottom policy. */
@Composable
private fun MessageList(
    messages: List<ChatMessage>,
    onOpenApp: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    var followMode by remember { mutableStateOf(true) }
    var userScrolled by remember { mutableStateOf(false) }
    val messageCount by rememberUpdatedState(messages.size)
    val scrollConnection = remember {
        object : NestedScrollConnection {
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                if (source == NestedScrollSource.UserInput) {
                    userScrolled = true
                    if (available.y > 0) followMode = false
                }
                return Offset.Zero
            }
        }
    }
    LaunchedEffect(listState) {
        snapshotFlow { Triple(listState.layoutInfo, followMode, listState.isScrollInProgress) }
            .collectLatest { (_, following, scrolling) ->
                if (!scrolling && userScrolled) {
                    if (!listState.canScrollForward) followMode = true
                    userScrolled = false
                }
                if (following && listState.canScrollForward) {
                    withFrameNanos { }
                    if (followMode) listState.scrollToItem(messageCount)
                }
            }
    }

    Box(modifier = modifier) {
        LazyColumn(
            modifier = Modifier.fillMaxSize().nestedScroll(scrollConnection),
            state = listState,
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(
                items = messages,
                key = { it.id }
            ) { message ->
                MessageBubble(
                    message = message,
                    onOpenApp = onOpenApp,
                    onInspect = { followMode = false; userScrolled = false },
                    modifier = Modifier.fillMaxWidth()
                )
            }
            item(key = "chat-bottom") { Spacer(Modifier.size(1.dp)) }
        }

        AnimatedVisibility(
            visible = !followMode && listState.canScrollForward,
            enter = fadeIn(animationSpec = tween(PocketPilotMotion.StatusFlip)),
            exit = fadeOut(animationSpec = tween(PocketPilotMotion.StatusFlip)),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp)
        ) {
            Surface(
                shape = CircleShape,
                shadowElevation = MaterialTheme.pocketPilot.elevation.floating,
                color = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
                modifier = Modifier
                    .size(48.dp)
                    .testTag("qa-live-pill")
                    .clickable(role = Role.Button) {
                        scope.launch {
                            listState.animateScrollToItem(messages.size)
                            followMode = true
                        }
                    }
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Rounded.KeyboardArrowDown,
                        contentDescription = "Scroll to bottom",
                        modifier = Modifier.size(24.dp)
                    )
                }
            }
        }
    }
}

/** Routes a Done/response tap from chat through the capsule before falling back to the ViewModel send. Pinned by ChatDoneBridgeTest —
 * the capsule step must run first so a stale WaitingFor* state clears (see commit d23537e8). */
internal fun forwardUserResponse(
    binding: id.steveimm.pocketpilot.ui.capsule.CapsuleBinding,
    sendUserResponse: (String, String) -> Unit,
    callId: String,
    response: String,
) {
    if (binding.onUserResponseSent(callId)) {
        sendUserResponse(callId, response)
    }
}
