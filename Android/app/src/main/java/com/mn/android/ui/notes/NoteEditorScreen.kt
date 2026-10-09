package com.mn.android.ui.notes

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
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
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.R
import com.mn.android.data.NoteEditorSource
import com.mn.android.ui.theme.MnTheme
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.debounce

/**
 * Port of the iOS NoteEditor without the AI draft bar (iOS itself ships it
 * over `AIDraftManagerStub`; there is no AI backend on Android yet — the
 * sparkles entry is omitted rather than rendered dead).
 *
 * Mirrors the ViewModel's rules exactly as presentation-local state:
 * - new note: never persisted while entirely blank (`hasContent`)
 * - autosave debounced 800 ms after the last change, only when dirty
 * - back button saves (when dirty), then pops
 * - delete is offered only for an existing note, behind a confirm dialog
 * - title normalisation (trim / "Untitled") is applied by Swift on save and
 *   the normalised value comes back into the field
 *
 * A new note's id is generated up front (NoteEditorSource.newId) instead of
 * lazily on first save as in EditTarget.new — same observable behaviour, and
 * it keeps every later save a simple upsert.
 */
@OptIn(FlowPreview::class)
@Composable
fun NoteEditorScreen(
    noteId: String?,
    onBack: () -> Unit,
) {
    val editingId = rememberSaveable { noteId ?: NoteEditorSource.newId() }
    val isNewNote = noteId == null

    var title by rememberSaveable { mutableStateOf("") }
    var body by rememberSaveable { mutableStateOf("") }
    var persisted by remember { mutableStateOf<NoteEditorSource.EditorNote?>(null) }
    var showDeleteConfirmation by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(noteId) {
        if (noteId != null) {
            NoteEditorSource.loadNote(noteId)?.let { note ->
                title = note.title
                body = note.content
                persisted = note
            }
        }
    }

    /** Kotlin mirror of NoteEditorViewModel.isDirty / hasContent. */
    fun isDirtyNow(currentTitle: String, currentBody: String): Boolean {
        val stored = persisted
        return if (stored == null) {
            currentTitle.isNotEmpty() || currentBody.isNotEmpty()
        } else {
            stored.title != normalizedTitle(currentTitle) || stored.content != currentBody
        }
    }

    fun hasContentNow(currentTitle: String, currentBody: String): Boolean =
        currentTitle.isNotBlank() || currentBody.isNotBlank()

    fun performSave() {
        // A blank new note is a mis-tap, never an intent (iOS: same rule).
        if (isNewNote && !hasContentNow(title, body)) return
        if (!isDirtyNow(title, body)) return
        val normalizedTitle = NoteEditorSource.save(editingId, title, body)
        if (normalizedTitle.isEmpty()) return
        if (normalizedTitle != title) title = normalizedTitle
        persisted = NoteEditorSource.EditorNote(editingId, normalizedTitle, body, persisted?.dateMillis ?: 0L)
    }

    // Autosave: debounced, only while dirty — 800 ms like the iOS ViewModel.
    LaunchedEffect(editingId) {
        snapshotFlow { title to body }
            .debounce(800)
            .collectLatest { (t, b) ->
                if (isDirtyNow(t, b)) {
                    // latest text, not the debounced snapshot, goes to disk
                    performSave()
                }
            }
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(MnTheme.background)
    ) {
        EditorTopBar(
            showDelete = !isNewNote,
            onBack = {
                performSave()
                onBack()
            },
            onDelete = { showDeleteConfirmation = true },
        )
        TitleField(
            title = title,
            onTitleChange = { title = it },
        )
        HorizontalDivider(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp),
            color = MnTheme.divider,
        )
        BodyField(
            body = body,
            onBodyChange = { body = it },
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
        )
    }

    if (showDeleteConfirmation) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = { Text(stringResource(R.string.delete_note_title)) },
            text = { Text(stringResource(R.string.delete_note_body)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteConfirmation = false
                        NoteEditorSource.delete(editingId)
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
        IconButton(
            onClick = onBack,
            modifier = Modifier.height(36.dp),
        ) {
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                contentDescription = stringResource(R.string.back),
                tint = MnTheme.textPrimary,
            )
        }
        if (showDelete) {
            IconButton(
                onClick = { menuExpanded = true },
                modifier = Modifier
                    .height(36.dp)
                    .align(androidx.compose.ui.Alignment.CenterEnd),
            ) {
                Icon(
                    Icons.Filled.MoreVert,
                    contentDescription = null,
                    tint = MnTheme.textPrimary,
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
private fun BodyField(body: String, onBodyChange: (String) -> Unit, modifier: Modifier = Modifier) {
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
        modifier = modifier.padding(horizontal = 8.dp),
    )
}

// MARK: - Domain mirrors

/**
 * Kotlin mirror of `NoteTitle.init`: trim, blank -> "Untitled". Used only for
 * the dirty check so an untouched "   " title does not look dirty; the value
 * object on the Swift side stays the single place that normalises for real.
 */
private fun normalizedTitle(raw: String): String =
    raw.trim().ifEmpty { "Untitled" }

// MARK: - Preview

@Preview(name = "Note editor")
@Composable
private fun NoteEditorPreview() {
    Column(Modifier.background(MnTheme.background)) {
        EditorTopBar(showDelete = true, onBack = {}, onDelete = {})
        TitleField(title = "Morning pages", onTitleChange = {})
        HorizontalDivider(color = MnTheme.divider)
        BodyField(body = "Breathe in, breathe out.", onBodyChange = {})
    }
}