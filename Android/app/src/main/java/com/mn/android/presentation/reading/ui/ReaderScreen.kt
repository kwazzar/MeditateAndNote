package com.mn.android.presentation.reading.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.FormatSize
import androidx.compose.material.icons.filled.List
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.sp
import com.mn.android.R
import com.mn.android.data.BookmarksSource
import com.mn.android.data.ReaderSettingsStore
import com.mn.android.data.TextMetrics
import com.mn.android.data.ReaderSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Port of the iOS `ReaderView` + `ReaderSettingsSheet`: paged text with tap
 * zones (left/back, center/chrome, right/forward), saved reading position,
 * font size + paper theme in a bottom sheet.
 *
 * Pagination happens in Swift (`ReaderSource`); this screen renders the lines
 * of one page and asks for a re-layout when the font size changes. Paper
 * palettes are feature constants (mirroring iOS `ReaderTheme`), not app-theme
 * tokens — the reader intentionally reads differently from the app chrome.
 */

private enum class ReaderPaper(
    val background: Color,
    val text: Color,
    val secondary: Color,
) {
    LIGHT(
        background = Color(0xFFFAFAF8),
        text = Color(0xFF1F1F21),
        secondary = Color(0xFF737374),
    ),
    SEPIA(
        background = Color(0xFFF5EBD1),
        text = Color(0xFF382A19),
        secondary = Color(0xFF7A6652),
    ),
    DARK(
        background = Color(0xFF171719),
        text = Color(0xFFE0DED9),
        secondary = Color(0xFF999795),
    ),
}

private fun clockText(): String =
    java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault())
        .format(java.util.Date())

// Chrome bars, like the FBReader menu: neutral gray bands over the page,
// identical in every paper theme (the page color never tints them).
private val chromeBackground = Color(0xFF3A3A40)
private val chromeContent = Color(0xFFF2F2F2)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalTextApi::class, ExperimentalFoundationApi::class)
@Composable
fun ReaderScreen(
    bookId: String,
    onBack: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var paper by rememberSaveable {
        mutableStateOf(
            ReaderSettingsStore.paper().let { name ->
                ReaderPaper.entries.firstOrNull { it.name == name } ?: ReaderPaper.SEPIA
            }
        )
    }
    var fontSize by rememberSaveable { mutableFloatStateOf(ReaderSettingsStore.fontSize()) }
    var showSettings by remember { mutableStateOf(false) }
    // Immersive by default, like the FBReader reference: chrome appears on a
    // center tap and hides again on the next one. Pagination reserves the same
    // bands either way, so toggling never rewraps the page.
    var showChrome by remember { mutableStateOf(false) }

    var title by remember { mutableStateOf("") }
    var pageCount by remember { mutableIntStateOf(0) }
    var page by remember { mutableIntStateOf(0) }
    var lines by remember { mutableStateOf<List<String>>(emptyList()) }
    var linePositions by remember { mutableStateOf<List<ReaderSource.LinePosition>>(emptyList()) }
    var progress by remember { mutableFloatStateOf(0f) }
    var loadFailed by remember { mutableStateOf(false) }
    var clock by remember { mutableStateOf(clockText()) }

    var chapters by remember { mutableStateOf<List<BookmarksSource.Chapter>>(emptyList()) }
    var marks by remember { mutableStateOf<List<BookmarksSource.Mark>>(emptyList()) }
    var showContents by remember { mutableStateOf(false) }
    var showMarks by remember { mutableStateOf(false) }
    var actionLine by remember { mutableStateOf<Int?>(null) }
    val scrollState = rememberScrollState()

    // Swift paginates in pixels (Android Paint metrics), so the page box and
    // the font size are converted to px — dp would wrap every line far too early.
    val configuration = androidx.compose.ui.platform.LocalConfiguration.current
    val localDensity = androidx.compose.ui.platform.LocalDensity.current
    val density = localDensity.density
    // The window is edge-to-edge (targetSdk 36), so screenWidthDp/screenHeightDp
    // include the system bars. The chrome buttons sit inside those bars, so the
    // text box has to leave room for status bar + icon row at the top and
    // navigation bar + page counter at the bottom — otherwise the icons end up
    // on top of the first lines and the last lines hide behind the gesture bar.
    val insetTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val insetBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    // Text uses the full column: the chrome bars float over it as gray bands
    // when invoked, so no band is reserved while reading.
    val contentTop = insetTop + 12.dp
    val contentBottom = insetBottom + 12.dp
    val pageWidth = (configuration.screenWidthDp - 40.0) * density
    val pageHeight =
        ((configuration.screenHeightDp - contentTop.value - contentBottom.value) * density).toDouble()
    // sp -> px through the Compose density: it carries the system font scale,
    // which the engine's Paint metrics must match or every line wraps early.
    val fontSizePx = with(localDensity) { fontSize.sp.toPx() }
    // The engine lays lines out with Paint metrics ((descent - ascent) * 1.45),
    // which is taller than Compose's fontSize * 1.45. Render every line at the
    // engine's advance, or the page ends short of the bottom edge.
    val lineHeightPx = remember(fontSizePx) { TextMetrics.lineHeight(fontSizePx.toDouble()).toFloat() }
    val lineHeightSp = with(localDensity) { lineHeightPx.toSp() }

    // The engine wraps with Paint metrics, the page renders with Compose
    // metrics, and the two differ by 5-10% on some devices. Measure one probe
    // string both ways and hand the ratio to the engine, so its lines are
    // exactly as wide as the renderer can paint.
    val textMeasurer = rememberTextMeasurer()
    val widthScale = remember(fontSizePx) {
        // The ratio is not perfectly uniform across strings (different glyph
        // mixes, kerning), so the worst probe wins: one line that is slightly
        // too wide would be re-wrapped by the renderer into an orphan word.
        val probes = listOf(
            "The quiet mind observes its own breath, and every thought passes.",
            "Chapter line 84. The quiet mind observes",
            "own breath and lets each thought pass like a",
            "ill1 O0 0123456789 — narrow: Wm",
        )
        // Floor of 1.02: the engine must wrap at almost exactly the renderer
        // width, so page lines fill the column edge to edge (like the FBReader
        // reference) instead of leaving a ragged right edge. The remaining 2%
        // guards the per-probe measurement drift that the worst-probe ratio
        // may still miss.
        var worst = 1.02
        for (probe in probes) {
            val composeWidth = textMeasurer.measure(
                text = probe,
                style = TextStyle(fontSize = fontSize.sp, fontFamily = FontFamily.Serif),
            ).size.width.toDouble()
            val paintWidth = TextMetrics.measure(probe, fontSizePx.toDouble())
            if (paintWidth > 0) {
                worst = maxOf(worst, composeWidth / paintWidth)
            }
        }
        worst * 1.01
    }

    suspend fun openBook() = withContext(Dispatchers.IO) {
        val opened = ReaderSource.open(bookId, fontSizePx.toDouble(), pageWidth, pageHeight, widthScale)
        title = opened.title
        pageCount = opened.pageCount
        page = opened.page
        val (pageLines, pagePositions, pageProgress) = ReaderSource.page(opened.page)
        lines = pageLines
        linePositions = pagePositions
        progress = pageProgress.toFloat()
    }

    LaunchedEffect(bookId) {
        runCatching {
            openBook()
            chapters = withContext(Dispatchers.IO) { BookmarksSource.readChapters(bookId) }
            marks = withContext(Dispatchers.IO) { BookmarksSource.readMarks(bookId) }
        }.onFailure {
            android.util.Log.e("ReaderScreen", "open failed", it)
            loadFailed = true
        }
    }

    // The clock sits in the footer; refresh it while the reader is open even
    // when the user is staring at one page for minutes at a time.
    LaunchedEffect(Unit) {
        while (true) {
            kotlinx.coroutines.delay(60_000)
            clock = clockText()
        }
    }

    fun showPage(index: Int) {
        val clamped = index.coerceIn(0, (pageCount - 1).coerceAtLeast(0))
        page = clamped
        clock = clockText()
        scope.launch {
            val (pageLines, pagePositions, pageProgress) = runCatching {
                withContext(Dispatchers.IO) { ReaderSource.page(clamped) }
            }.getOrNull() ?: Triple(emptyList<String>(), emptyList<ReaderSource.LinePosition>(), 0.0)
            lines = pageLines
            linePositions = pagePositions
            progress = pageProgress.toFloat()
            withContext(Dispatchers.IO) { ReaderSource.savePosition(bookId, clamped) }
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            // Position is saved on every page turn; the dispose hook only
            // covers a reader closed without turning a page.
            if (pageCount > 0) {
                ReaderSource.savePosition(bookId, page)
            }
        }
    }

    if (loadFailed) {
        Column(
            Modifier
                .fillMaxSize()
                .background(paper.background)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(stringResource(R.string.reader_open_failed), color = paper.text)
            Spacer(Modifier.padding(8.dp))
            Button(onClick = onBack) { Text(stringResource(R.string.close)) }
        }
        return
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(paper.background)
            // One handler for the whole page: a tap turns the page (left /
            // right thirds) or toggles the chrome (center), a long press opens
            // the actions for the line under the finger. Separate overlays
            // would swallow the long press before the text sees it.
            .pointerInput(pageCount) {
                detectTapGestures(
                    onTap = { offset ->
                        val third = size.width / 3f
                        when {
                            offset.x < third -> showPage(page - 1)
                            offset.x > third * 2 -> showPage(page + 1)
                            else -> showChrome = !showChrome
                        }
                    },
                    onLongPress = { offset ->
                        val topPaddingPx = with(density) { contentTop.toPx() }
                        if (lineHeightPx > 0 && lines.isNotEmpty()) {
                            val index = ((offset.y + scrollState.value - topPaddingPx) / lineHeightPx)
                                .toInt()
                                .coerceIn(0, lines.lastIndex)
                            actionLine = index
                        }
                    },
                )
            }
            // Swipe left / right turns the page, like the iOS reader. The
            // scrollable text column keeps the vertical drags, so the two
            // never fight: horizontal movement is unclaimed by it.
            .pointerInput(pageCount) {
                var dragX = 0f
                detectHorizontalDragGestures(
                    onDragStart = { dragX = 0f },
                    onHorizontalDrag = { _, delta -> dragX += delta },
                    onDragEnd = {
                        val threshold = 48.dp.toPx()
                        when {
                            dragX < -threshold -> showPage(page + 1)
                            dragX > threshold -> showPage(page - 1)
                        }
                    },
                )
            }
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(
                    start = 20.dp,
                    end = 20.dp,
                    top = contentTop,
                    bottom = contentBottom,
                ),
        ) {
            lines.forEach { line ->
                Text(
                    line,
                    color = paper.text,
                    fontSize = fontSize.sp,
                    fontFamily = FontFamily.Serif,
                    lineHeight = lineHeightSp,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }

        if (showChrome) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(chromeBackground)
                    .statusBarsPadding()
                    .padding(horizontal = 8.dp, vertical = 4.dp)
                    .align(Alignment.TopCenter),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = stringResource(R.string.back),
                        tint = chromeContent,
                    )
                }
                Spacer(Modifier.weight(1f))
                // Same order as the iOS chrome: contents, marks, settings.
                IconButton(onClick = {
                    showContents = true
                    scope.launch {
                        chapters = withContext(Dispatchers.IO) { BookmarksSource.readChapters(bookId) }
                    }
                }) {
                    Icon(
                        Icons.Filled.List,
                        contentDescription = stringResource(R.string.reader_contents),
                        tint = chromeContent,
                    )
                }
                IconButton(onClick = {
                    showMarks = true
                    scope.launch {
                        marks = withContext(Dispatchers.IO) { BookmarksSource.readMarks(bookId) }
                    }
                }) {
                    Icon(
                        Icons.Filled.Bookmark,
                        contentDescription = stringResource(R.string.reader_bookmarks),
                        tint = chromeContent,
                    )
                }
                IconButton(onClick = { showSettings = true }) {
                    Icon(
                        Icons.Filled.FormatSize,
                        contentDescription = stringResource(R.string.reader_font_size),
                        tint = chromeContent,
                    )
                }
            }
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(chromeBackground)
                    .navigationBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 10.dp)
                    .align(Alignment.BottomCenter),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.reader_page_format, page + 1, pageCount),
                    color = chromeContent.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.labelMedium,
                )
                LinearProgressIndicator(
                    progress = { progress },
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = 12.dp),
                    trackColor = chromeContent.copy(alpha = 0.24f),
                    color = chromeContent,
                )
                Text(
                    clock,
                    color = chromeContent.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.labelMedium,
                )
            }
        }
    }

    if (showContents) {
        TableOfContentsSheet(
            chapters = chapters,
            currentPage = page,
            onSelect = { chapter ->
                showPage(chapter.page)
                showContents = false
            },
            onDismiss = { showContents = false },
        )
    }

    if (showMarks) {
        ReaderMarksSheet(
            marks = marks,
            onSelect = { mark ->
                scope.launch {
                    val target = withContext(Dispatchers.IO) {
                        BookmarksSource.pageForPosition(mark.chapter, mark.block, mark.offset)
                    }
                    showPage(target)
                }
                showMarks = false
            },
            onDelete = { mark ->
                scope.launch {
                    withContext(Dispatchers.IO) { BookmarksSource.delete(mark.id) }
                    marks = withContext(Dispatchers.IO) { BookmarksSource.readMarks(bookId) }
                }
            },
            onDismiss = { showMarks = false },
        )
    }

    actionLine?.let { index ->
        val line = lines.getOrNull(index).orEmpty()
        val position = linePositions.getOrNull(index)
        LineActionsSheet(
            lineText = line,
            onHighlight = {
                scope.launch {
                    withContext(Dispatchers.IO) {
                        BookmarksSource.addHighlight(
                            bookId = bookId,
                            chapter = position?.chapter ?: 0,
                            block = position?.block ?: 0,
                            offset = position?.offset ?: 0,
                            text = line,
                            bookTitle = title,
                            location = "page ${page + 1}",
                            asNote = false,
                        )
                    }
                    marks = withContext(Dispatchers.IO) { BookmarksSource.readMarks(bookId) }
                }
                actionLine = null
            },
            onAddToNotes = {
                scope.launch {
                    withContext(Dispatchers.IO) {
                        BookmarksSource.addHighlight(
                            bookId = bookId,
                            chapter = position?.chapter ?: 0,
                            block = position?.block ?: 0,
                            offset = position?.offset ?: 0,
                            text = line,
                            bookTitle = title,
                            location = "page ${page + 1}",
                            asNote = true,
                        )
                    }
                    marks = withContext(Dispatchers.IO) { BookmarksSource.readMarks(bookId) }
                }
                actionLine = null
            },
            onBookmarkPage = {
                scope.launch {
                    withContext(Dispatchers.IO) {
                        BookmarksSource.addPageBookmark(bookId, 0, 0, 0)
                    }
                    marks = withContext(Dispatchers.IO) { BookmarksSource.readMarks(bookId) }
                }
                actionLine = null
            },
            onDismiss = { actionLine = null },
        )
    }

    if (showSettings) {
        ModalBottomSheet(onDismissRequest = { showSettings = false }) {
            Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text(stringResource(R.string.reader_font_size), fontWeight = FontWeight.Medium)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("A", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface)
                    Slider(
                        value = fontSize,
                        onValueChange = { fontSize = it },
                        onValueChangeFinished = {
                            ReaderSettingsStore.setFontSize(fontSize)
                            scope.launch {
                                val result = runCatching {
                                    withContext(Dispatchers.IO) {
                                        ReaderSource.repaginate(bookId, fontSizePx.toDouble(), pageWidth, pageHeight, widthScale)
                                    }
                                }.getOrNull()
                                if (result != null) {
                                    pageCount = result.first
                                    showPage(result.second)
                                }
                            }
                        },
                        valueRange = 12f..32f,
                        modifier = Modifier.weight(1f),
                    )
                    Text("A", fontSize = 24.sp, color = MaterialTheme.colorScheme.onSurface)
                }
                Text(stringResource(R.string.reader_paper), fontWeight = FontWeight.Medium)
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    ReaderPaper.entries.forEach { candidate ->
                        val selected = paper == candidate
                        Button(
                            onClick = {
                                paper = candidate
                                ReaderSettingsStore.setPaper(candidate.name)
                            },
                            border = if (selected) {
                                androidx.compose.foundation.BorderStroke(
                                    2.dp,
                                    MaterialTheme.colorScheme.primary,
                                )
                            } else {
                                null
                            },
                            colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                                containerColor = candidate.background,
                                contentColor = candidate.text,
                            ),
                        ) {
                            Text(
                                when (candidate) {
                                    ReaderPaper.LIGHT -> stringResource(R.string.reader_paper_light)
                                    ReaderPaper.SEPIA -> stringResource(R.string.reader_paper_sepia)
                                    ReaderPaper.DARK -> stringResource(R.string.reader_paper_dark)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}
