package com.mn.android.presentation.reading.ui

import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.mn.android.R
import com.mn.android.application.container.AppContainer
import com.mn.android.domain.book.BookId
import com.mn.android.presentation.reading.viewmodel.LibraryViewModel
import com.mn.android.presentation.theme.ui.MnBackground
import kotlinx.coroutines.launch

/**
 * Port of the iOS `LibraryView`: cover grid, import from the system picker,
 * per-book progress, long-press delete.
 *
 * All book state flows through [BookRepository] (Swift via JNI); this screen only
 * holds which books are shown and which dialogs are up.
 */

/** One library cell: the summary plus the decoded cover. */
private data class LibraryBook(
    val id: BookId,
    val title: String,
    val author: String,
    val format: String,
    val progressPerMille: Int,
    val cover: android.graphics.Bitmap?,
)

/**
 * The picked document's file name — the MIME type carries no extension, and
 * the extension is what decides the import format.
 */
internal fun documentName(context: android.content.Context, uri: android.net.Uri): String {
    if (uri.scheme != "file") {
        context.contentResolver
            .query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) {
                    return cursor.getString(index) ?: "book"
                }
            }
    }
    return uri.lastPathSegment ?: "book"
}

@Composable
fun LibraryScreen(
    onOpenBook: (String) -> Unit,
) {
    val context = LocalContext.current
    val viewModel: LibraryViewModel = viewModel(
        factory = viewModelFactory {
            initializer { AppContainer.makeLibraryViewModel(context) }
        },
    )
    val scope = rememberCoroutineScope()
    val state by viewModel.state.collectAsState()
    var pendingDelete by remember { mutableStateOf<LibraryBook?>(null) }

    // The covers are bytes in the ViewModel; the bitmaps are the screen's.
    val books = remember(state.books, state.covers) {
        state.books.map { summary ->
            LibraryBook(
                id = summary.id,
                title = summary.title,
                author = summary.author,
                format = summary.format,
                progressPerMille = summary.progressPerMille,
                cover = state.covers[summary.id]?.let {
                    BitmapFactory.decodeByteArray(it, 0, it.size)
                },
            )
        }
    }

    val importer = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val name = documentName(context, uri)
            val content = context.contentResolver.openInputStream(uri)
            if (content == null) {
                viewModel.reportImportFailure()
            } else {
                viewModel.import(name, content)
            }
        }
    }

    Box(Modifier.fillMaxSize()) {
        // Same themed background as the tab-bar screens; a plain Material
        // color made the library visibly mismatch the bar behind it.
        MnBackground()
        if (books.isEmpty()) {
            Column(
                Modifier
                    .align(Alignment.Center)
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(stringResource(R.string.no_books_yet), style = MaterialTheme.typography.headlineSmall)
                Text(
                    stringResource(R.string.no_books_hint),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Button(onClick = { importer.launch(arrayOf("*/*")) }) {
                    Text(stringResource(R.string.import_book))
                }
            }
        } else {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(110.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    start = 16.dp, end = 16.dp, top = 64.dp, bottom = 120.dp,
                ),
                modifier = Modifier.fillMaxSize(),
            ) {
                items(books, key = { it.id.value }) { book ->
                    BookCell(
                        book = book,
                        onOpen = { onOpenBook(book.id.value) },
                        onDelete = { pendingDelete = book },
                    )
                }
            }
        }

        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .align(Alignment.TopCenter),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.library),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Spacer(Modifier.weight(1f))
            IconButton(onClick = { importer.launch(arrayOf("*/*")) }) {
                Icon(
                    Icons.Filled.Add,
                    contentDescription = stringResource(R.string.import_book),
                    tint = Color.White,
                )
            }
        }
    }

    if (state.importFailed) {
        AlertDialog(
            onDismissRequest = { viewModel.dismissImportError() },
            confirmButton = {
                Button(onClick = { viewModel.dismissImportError() }) { Text(stringResource(R.string.ok)) }
            },
            title = { Text(stringResource(R.string.import_failed)) },
            text = { Text(stringResource(R.string.import_failed_hint)) },
        )
    }

    pendingDelete?.let { book ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            confirmButton = {
                Button(onClick = {
                    viewModel.delete(book.id)
                    pendingDelete = null
                }) { Text(stringResource(R.string.delete)) }
            },
            dismissButton = {
                Button(onClick = { pendingDelete = null }) { Text(stringResource(R.string.cancel)) }
            },
            title = { Text(stringResource(R.string.delete_book_title)) },
            text = { Text(book.title) },
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun BookCell(
    book: LibraryBook,
    onOpen: () -> Unit,
    onDelete: () -> Unit,
) {
    Column(
        Modifier
            .combinedClickable(onClick = onOpen, onLongClick = onDelete)
    ) {
        Box(
            Modifier
                .aspectRatio(0.7f)
                .clip(RoundedCornerShape(8.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            if (book.cover != null) {
                Image(
                    bitmap = book.cover.asImageBitmap(),
                    contentDescription = book.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } else {
                Text(
                    book.title.take(1),
                    style = MaterialTheme.typography.headlineMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (book.progressPerMille > 0) {
                Text(
                    stringResource(R.string.percent_format, book.progressPerMille / 10),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(6.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(Color.Black.copy(alpha = 0.55f))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(
            book.title,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onBackground,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        if (book.author.isNotEmpty()) {
            Text(
                book.author,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
