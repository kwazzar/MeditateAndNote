package com.mn.android.presentation.reading.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mn.android.R
import com.mn.android.data.BookmarksSource
import java.text.DateFormat
import java.util.Date

/**
 * The reader's table of contents: chapters with the page each one starts on.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TableOfContentsSheet(
    chapters: List<BookmarksSource.Chapter>,
    currentPage: Int,
    onSelect: (BookmarksSource.Chapter) -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.padding(horizontal = 20.dp)) {
            Text(
                stringResource(R.string.reader_contents),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            LazyColumn(Modifier.padding(top = 8.dp)) {
                items(chapters, key = { it.chapter }) { chapter ->
                    TextButton(
                        onClick = { onSelect(chapter) },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                chapter.title,
                                modifier = Modifier.weight(1f),
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            if (chapter.page == currentPage) {
                                Text(
                                    stringResource(R.string.reader_on_this_page),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            } else {
                                Text(
                                    "${chapter.page + 1}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.padding(bottom = 24.dp))
        }
    }
}

/**
 * The reader's marks: page bookmarks and passage highlights.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReaderMarksSheet(
    marks: List<BookmarksSource.Mark>,
    onSelect: (BookmarksSource.Mark) -> Unit,
    onDelete: (BookmarksSource.Mark) -> Unit,
    onDismiss: () -> Unit,
) {
    var pendingDelete by remember { mutableStateOf<BookmarksSource.Mark?>(null) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.padding(horizontal = 20.dp)) {
            Text(
                stringResource(R.string.reader_bookmarks),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            if (marks.isEmpty()) {
                Text(
                    stringResource(R.string.reader_marks_empty),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 24.dp),
                )
            }
            LazyColumn(Modifier.padding(top = 8.dp)) {
                items(marks, key = { it.id }) { mark ->
                    Column {
                        TextButton(
                            onClick = { onSelect(mark) },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    if (mark.isHighlight) {
                                        Text(
                                            mark.text,
                                            maxLines = 2,
                                            overflow = TextOverflow.Ellipsis,
                                            color = MaterialTheme.colorScheme.onSurface,
                                        )
                                    } else {
                                        Text(
                                            stringResource(R.string.reader_page_mark),
                                            color = MaterialTheme.colorScheme.onSurface,
                                        )
                                    }
                                    Text(
                                        DateFormat.getDateTimeInstance(
                                            DateFormat.SHORT,
                                            DateFormat.SHORT,
                                        ).format(Date(mark.createdAtMillis)),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                if (mark.noteId.isNotEmpty()) {
                                    Text(
                                        stringResource(R.string.reader_has_note),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.primary,
                                    )
                                }
                            }
                        }
                        TextButton(
                            onClick = { pendingDelete = mark },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(
                                stringResource(R.string.delete),
                                color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.labelSmall,
                            )
                        }
                        HorizontalDivider()
                    }
                }
            }
            Spacer(Modifier.padding(bottom = 24.dp))
        }
    }

    pendingDelete?.let { mark ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            confirmButton = {
                Button(onClick = {
                    onDelete(mark)
                    pendingDelete = null
                }) { Text(stringResource(R.string.delete)) }
            },
            dismissButton = {
                Button(onClick = { pendingDelete = null }) { Text(stringResource(R.string.cancel)) }
            },
            title = { Text(stringResource(R.string.reader_delete_mark_title)) },
            text = { Text(stringResource(R.string.reader_delete_mark_body)) },
        )
    }
}

/**
 * The actions for a long-pressed line: highlight it, turn it into a note, or
 * bookmark the page it sits on.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LineActionsSheet(
    lineText: String,
    onHighlight: () -> Unit,
    onAddToNotes: () -> Unit,
    onBookmarkPage: () -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.padding(horizontal = 20.dp)) {
            Text(
                lineText,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.padding(vertical = 12.dp))
            TextButton(onClick = onHighlight, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.reader_highlight))
            }
            TextButton(onClick = onAddToNotes, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.reader_add_to_notes))
            }
            TextButton(onClick = onBookmarkPage, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.reader_bookmark_page))
            }
            Spacer(Modifier.padding(bottom = 24.dp))
        }
    }
}
