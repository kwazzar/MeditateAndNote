package com.mn.android.presentation.notes.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.R
import com.mn.android.application.container.AppContainer
import com.mn.android.presentation.notes.viewmodel.NoteEditorViewModel
import com.mn.android.presentation.theme.ui.MnBackground
import com.mn.android.presentation.theme.ui.MnBackButton
import com.mn.android.presentation.theme.ui.MnTheme
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory

/**
 * Port of the iOS NoteEditor, AI draft bar included.
 *
 * The screen draws the state and forwards the taps: the rules live in
 * [NoteEditorViewModel]. The domain itself is not implemented here — Swift
 * owns it (the session, the free-quota rule, the parsing of the model's
 * answer) and Kotlin drives the commands and renders the answer. The provider
 * is a remote OpenAI-compatible endpoint the user configures in Settings.
 *
 * The rules the ViewModel keeps:
 * - new note: never persisted while entirely blank (`hasContent`)
 * - autosave debounced 800 ms after the last change, only when dirty
 * - back button saves (when dirty), then pops
 * - delete is offered only for an existing note, behind a confirm dialog
 * - title normalisation (trim / "Untitled") is applied by Swift on save and
 *   the normalised value comes back into the field
 */
@Composable
fun NoteEditorScreen(
    noteId: String?,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val vm: NoteEditorViewModel = viewModel(
        factory = viewModelFactory {
            initializer {
                AppContainer.makeNoteEditorViewModel(
                    context = context,
                    savedStateHandle = createSavedStateHandle(),
                    noteId = noteId,
                )
            }
        }
    )
    val state by vm.state.collectAsStateWithLifecycle()
    var showDeleteConfirmation by rememberSaveable { mutableStateOf(false) }

    Box(Modifier.fillMaxSize()) {
        MnBackground()
        Column(
            Modifier
                .fillMaxSize()
                // The keyboard covers the bottom of the window: the AI draft
                // bar has to sit above it, or the proposals are invisible.
                .imePadding(),
        ) {
            EditorTopBar(
                showDelete = state.canDelete,
                isDrafting = state.draft.isGenerating,
                onAiDraft = { vm.startDraft() },
                onBack = {
                    vm.save()
                    onBack()
                },
                onDelete = { showDeleteConfirmation = true },
            )
            TitleField(
                title = state.title,
                onTitleChange = { vm.onTitleChange(it) },
            )
            HorizontalDivider(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp),
                color = MnTheme.divider,
            )
            BodyField(
                body = state.body,
                onBodyChange = { vm.onBodyChange(it) },
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                autoFocus = true, // iOS: isEditorFocused = true on appear
            )
            AIDraftBar(
                isGenerating = state.draft.isGenerating,
                session = state.draft.session,
                error = state.draft.error,
                onAccept = { vm.acceptSuggestion(it) },
                onRemove = { vm.removeSuggestion(it) },
                onAcceptAll = { vm.acceptAllSuggestions() },
                onTransfer = { vm.transferAccepted() },
            )
        }
    }

    if (showDeleteConfirmation) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = { Text(stringResource(R.string.delete_note_title), color = MnTheme.textPrimary) },
            text = { Text(stringResource(R.string.delete_note_body), color = MnTheme.textSecondary) },
            containerColor = MnTheme.background,
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteConfirmation = false
                        vm.delete()
                        onBack()
                    },
                ) {
                    Text(
                        stringResource(R.string.delete),
                        color = MnTheme.deleteRed,
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmation = false }) {
                    Text(stringResource(R.string.cancel))
                }
            },
        )
    }
}

// MARK: - Top bar

@Composable
private fun EditorTopBar(
    showDelete: Boolean,
    isDrafting: Boolean,
    onAiDraft: () -> Unit,
    onBack: () -> Unit,
    onDelete: () -> Unit,
) {
    var menuExpanded by remember { mutableStateOf(false) }

    Box(
        Modifier
            .fillMaxWidth()
            .height(50.dp)
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        MnBackButton(onClick = onBack)
        Row(
            Modifier
                .height(36.dp)
                .align(androidx.compose.ui.Alignment.CenterEnd),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            // iOS: the sparkles in the top bar, a spinner while generating.
            IconButton(onClick = onAiDraft, enabled = !isDrafting) {
                if (isDrafting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp,
                        color = MnTheme.iconPrimary,
                    )
                } else {
                    Icon(
                        Icons.Filled.AutoAwesome,
                        contentDescription = stringResource(R.string.ai_draft_button),
                        tint = MnTheme.iconPrimary,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
            if (showDelete) {
                IconButton(onClick = { menuExpanded = true }) {
                    Icon(
                        Icons.Filled.MoreVert,
                        contentDescription = null,
                        tint = MnTheme.iconPrimary,
                    )
                    DropdownMenu(
                        expanded = menuExpanded,
                        onDismissRequest = { menuExpanded = false },
                    ) {
                        DropdownMenuItem(
                            text = {
                                Text(stringResource(R.string.delete), color = MnTheme.deleteRed)
                            },
                            onClick = {
                                menuExpanded = false
                                onDelete()
                            },
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Fields

@Composable
private fun TitleField(title: String, onTitleChange: (String) -> Unit) {
    TextField(
        value = title,
        onValueChange = onTitleChange,
        placeholder = {
            Text(
                stringResource(R.string.note_title_hint),
                color = MnTheme.textSecondary,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        },
        textStyle = MaterialTheme.typography.headlineSmall.copy(
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        ),
        singleLine = true,
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            focusedTextColor = MnTheme.textPrimary,
            unfocusedTextColor = MnTheme.textPrimary,
            cursorColor = MnTheme.streakActiveMeditation,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
        ),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp),
    )
}

@Composable
private fun BodyField(
    body: String,
    onBodyChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    autoFocus: Boolean = false,
) {
    val focusRequester = remember { FocusRequester() }
    if (autoFocus) {
        LaunchedEffect(Unit) {
            // Let the navigation transition settle before stealing focus —
            // requesting during it drops the request on some API levels.
            kotlinx.coroutines.delay(250)
            runCatching { focusRequester.requestFocus() }
        }
    }
    TextField(
        value = body,
        onValueChange = onBodyChange,
        placeholder = {
            Text(
                stringResource(R.string.note_body_hint),
                color = MnTheme.textSecondary,
            )
        },
        textStyle = MaterialTheme.typography.bodyLarge,
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            focusedTextColor = MnTheme.textPrimary,
            unfocusedTextColor = MnTheme.textPrimary,
            cursorColor = MnTheme.streakActiveMeditation,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
        ),
        modifier = modifier
            .padding(horizontal = 8.dp)
            .then(if (autoFocus) Modifier.focusRequester(focusRequester) else Modifier),
    )
}

// MARK: - Preview

@Preview(name = "Note editor")
@Composable
private fun NoteEditorPreview() {
    Column(Modifier.background(MnTheme.background)) {
        EditorTopBar(showDelete = true, isDrafting = false, onAiDraft = {}, onBack = {}, onDelete = {})
        TitleField(title = "Morning pages", onTitleChange = {})
        HorizontalDivider(color = MnTheme.divider)
        BodyField(body = "Breathe in, breathe out.", onBodyChange = {})
    }
}