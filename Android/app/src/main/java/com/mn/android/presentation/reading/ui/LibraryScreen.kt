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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import com.mn.android.R
import com.mn.android.data.BookSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Port of the iOS `LibraryView`: cover grid, import from the system picker,
 * per-book progress, long-press delete.
 *
 * All book state flows through `BookSource` (Swift via JNI); this screen only
 * holds which books are shown and which dialogs are up.
 */

/** Reader paper palette entry used by the cover placeholder. */
private data class LibraryBook(
    val id: String,
    val title: String,
    val author: String,
    val format: String,
    val progressPerMille: Int,
    val cover: android.graphics.Bitmap?,
)

@Composable
fun LibraryScreen(
    onOpenBook: (String) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var books by remember { mutableStateOf<List<LibraryBook>>(emptyList()) }
    var importError by remember { mutableStateOf(false) }
    var pendingDelete by remember { mutableStateOf<LibraryBook?>(null) }

    suspend fun reload() = withContext(Dispatchers.IO) {
        val records = BookSource.readLibrary()
        records.map { record ->
            LibraryBook(
                id = record.id,
                title = record.title,
                author = record.author,
                format = record.format,
                progressPerMille = record.progressPerMille,
                cover = BookSource.cover(record.id)?.let {
                    BitmapFactory.decodeByteArray(it, 0, it.size)
                },
            )
        }
    }

    LaunchedEffect(Unit) {
        runCatching { books = reload() }
    }

    val importer = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val result = runCatching {
                withContext(Dispatchers.IO) {
                    val ext = (context.contentResolver.getType(uri) ?: uri.toString())
                        .substringAfterLast('.', "")
                        .substringAfterLast('/')
                        .lowercase()
                    val temp = java.io.File(context.cacheDir, "import.${ext}")
                    context.contentResolver.openInputStream(uri)?.use { input ->
                        temp.outputStream().use { output -> input.copyTo(output) }
                    } ?: error("cannot read picked file")
                    val format = when (ext) {
                        "epub" -> "epub"
                        "txt" -> "txt"
                        else -> "fb2"
                    }
                    BookSource.import(temp.absolutePath, format)
                }
            }
            if (result.isSuccess) {
                runCatching { books = reload() }
            } else {
                importError = true
            }
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
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
                items(books, key = { it.id }) { book ->
                    BookCell(
                        book = book,
                        onOpen = { onOpenBook(book.id) },
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
            Button(onClick = { importer.launch(arrayOf("*/*")) }) {
                Text("+")
            }
        }
    }

    if (importError) {
        AlertDialog(
            onDismissRequest = { importError = false },
            confirmButton = {
                Button(onClick = { importError = false }) { Text(stringResource(R.string.ok)) }
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
                    scope.launch {
                        withContext(Dispatchers.IO) { BookSource.delete(book.id) }
                        runCatching { books = reload() }
                        pendingDelete = null
                    }
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
