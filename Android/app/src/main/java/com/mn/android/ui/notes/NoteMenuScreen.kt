package com.mn.android.ui.notes

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.mn.android.R
import com.mn.android.data.NoteMenuSource
import com.mn.android.ui.theme.MnTheme
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * Port of the iOS NoteMenu: search bar, the note cards list and the
 * Add Note capsule. Row tap opens the note, Add Note opens the editor.
 *
 * Loads on every entry to this destination — the manual reload fallback for
 * the DomainEventBus that is not ported yet; the bus wiring replaces this
 * when it lands.
 */
@Composable
fun NoteMenuScreen(
    onOpenNote: (String) -> Unit,
    onAddNote: () -> Unit,
) {
    var query by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf<List<NoteMenuSource.NoteRecord>>(emptyList()) }

    // Manual reload fallback: reloads every time this screen resumes —
    // covers both tab switches and popping back from the pushed note editor
    // (the editor destination stays composed under neither; without this the
    // stale list would render after a save). Replaced by DomainEventBus wiring
    // when it lands.
    LifecycleResumeEffect(Unit) {
        notes = NoteMenuSource.readMenu().notes
        onPauseOrDispose { }
    }

    val shown = remember(notes, query) {
        val q = query.trim()
        if (q.isEmpty()) notes
        else notes.filter {
            it.title.contains(q, ignoreCase = true) ||
                it.content.contains(q, ignoreCase = true)
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(MnTheme.background)
    ) {
        Column(Modifier.fillMaxSize()) {
            NotesSearchBar(
                query = query,
                onQueryChange = { query = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            )
            LazyColumn(
                Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(shown, key = { it.id }) { note ->
                    NoteCard(
                        note = note,
                        onClick = { onOpenNote(note.id) },
                    )
                }
            }
        }
        AddNoteButton(
            onClick = onAddNote,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(bottom = 16.dp, end = 26.dp),
        )
    }
}

// MARK: - Search bar

@Composable
private fun NotesSearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    OutlinedTextField(
        value = query,
        onValueChange = onQueryChange,
        placeholder = {
            Text(stringResource(R.string.search_notes_hint), color = MnTheme.textSecondary)
        },
        leadingIcon = {
            Icon(
                Icons.Filled.Search,
                contentDescription = null,
                tint = MnTheme.textSecondary,
            )
        },
        trailingIcon = {
            if (query.isNotEmpty()) {
                IconButton(onClick = { onQueryChange("") }) {
                    Icon(
                        Icons.Filled.Clear,
                        contentDescription = stringResource(R.string.clear_search),
                        tint = MnTheme.textSecondary,
                    )
                }
            }
        },
        singleLine = true,
        shape = RoundedCornerShape(12.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = MnTheme.textPrimary,
            unfocusedTextColor = MnTheme.textPrimary,
            cursorColor = MnTheme.streakActiveMeditation,
            focusedBorderColor = MnTheme.divider,
            unfocusedBorderColor = MnTheme.divider,
            focusedContainerColor = MnTheme.cardBackground,
            unfocusedContainerColor = MnTheme.cardBackground,
        ),
        modifier = modifier,
    )
}

// MARK: - Note card (NoteCard)

@Composable
private fun NoteCard(note: NoteMenuSource.NoteRecord, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val dateLabel = remember(note.dateMillis) {
        SimpleDateFormat("d MMMM", Locale.getDefault()).format(note.dateMillis)
    }

    Column(
        modifier
            .shadow(5.dp, RoundedCornerShape(12.dp))
            .border(2.dp, MnTheme.divider, RoundedCornerShape(12.dp))
            .background(MnTheme.cardBackground, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick),
    ) {
        Text(
            note.content.ifBlank { note.title },
            color = MnTheme.textSecondary,
            style = MaterialTheme.typography.bodyMedium,
            maxLines = 5,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .padding(14.dp),
        )
        Row(
            Modifier
                .fillMaxWidth()
                .border(1.dp, MnTheme.divider)
                .padding(horizontal = 14.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                dateLabel,
                style = MaterialTheme.typography.labelSmall,
                color = MnTheme.textSecondary,
            )
            Spacer(Modifier.weight(1f))
            Text(
                note.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MnTheme.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(R.string.read),
                style = MaterialTheme.typography.labelSmall,
                color = MnTheme.textSecondary,
            )
            Spacer(Modifier.width(2.dp))
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MnTheme.textPrimary,
                modifier = Modifier.size(16.dp),
            )
        }
    }
}

// MARK: - Add Note

@Composable
private fun AddNoteButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .height(44.dp)
            .background(MnTheme.cardBackground, CircleShape)
            .border(1.dp, MnTheme.divider, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            stringResource(R.string.add_note),
            style = MaterialTheme.typography.titleMedium,
            color = MnTheme.textPrimary,
        )
    }
}

// MARK: - Previews

@Preview(name = "Note menu")
@Composable
private fun NoteMenuPreview() {
    val sample = listOf(
        NoteMenuSource.NoteRecord("1", "Morning pages", "Breathe in, breathe out.\nToday the light came early.", 1_700_000_000_000),
        NoteMenuSource.NoteRecord("2", "Gratitude", "Warm tea, quiet room.", 1_690_000_000_000),
    )
    Column(Modifier.background(MnTheme.background)) {
        NotesSearchBar(query = "", onQueryChange = {})
        sample.forEach { NoteCard(note = it, onClick = {}) }
    }
}