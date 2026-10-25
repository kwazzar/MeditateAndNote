package com.mn.android.presentation.reading.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.mn.android.R
import com.mn.android.data.BookmarksSource
import com.mn.android.data.ReaderSettingsStore
import com.mn.android.data.TextMetrics
import com.mn.android.data.ReaderSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.distinctUntilChanged
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

private class PageLines(
    val lines: List<String>,
    val positions: List<ReaderSource.LinePosition>,
)

private fun clockText(): String =
    java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault())
        .format(java.util.Date())

// Chrome bars, like the FBReader menu: neutral gray bands over the page,
// identical in every paper theme (the page color never tints them).
private val chromeBackground = Color(0xFF3A3A40)
private val chromeContent = Color(0xFFF2F2F2)

private tailrec fun android.content.Context.findActivity(): android.app.Activity? = when (this) {
    is android.app.Activity -> this
    is android.content.ContextWrapper -> baseContext.findActivity()
    else -> null
}

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

    // Two reading modes: page-by-page (FBReader-style boxes) or one continuous
    // column of the whole book that the reader scrolls vertically.
    var scrollMode by rememberSaveable { mutableStateOf(ReaderSettingsStore.scrollMode()) }

    var title by remember { mutableStateOf("") }
    var pageCount by remember { mutableIntStateOf(0) }
    var page by remember { mutableIntStateOf(0) }
    var lines by remember { mutableStateOf<List<String>>(emptyList()) }
    var linePositions by remember { mutableStateOf<List<ReaderSource.LinePosition>>(emptyList()) }
    var progress by remember { mutableFloatStateOf(0f) }
    var loadFailed by remember { mutableStateOf(false) }
    var clock by remember { mutableStateOf(clockText()) }

    // Full-screen reading: system bars follow the chrome — hidden while reading,
    // back together with the gray bands so the status icons line up above them.
    val view = androidx.compose.ui.platform.LocalView.current
    LaunchedEffect(showChrome) {
        val window = view.context.findActivity()?.window ?: return@LaunchedEffect
        val controller = androidx.core.view.WindowCompat.getInsetsController(window, view)
        controller.systemBarsBehavior =
            androidx.core.view.WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        if (showChrome) {
            controller.show(androidx.core.view.WindowInsetsCompat.Type.systemBars())
        } else {
            controller.hide(androidx.core.view.WindowInsetsCompat.Type.systemBars())
        }
    }
    // Leaving the reader must restore the app chrome for the screens behind it.
    DisposableEffect(Unit) {
        onDispose {
            val window = view.context.findActivity()?.window
            if (window != null) {
                androidx.core.view.WindowCompat.getInsetsController(window, view)
                    .show(androidx.core.view.WindowInsetsCompat.Type.systemBars())
            }
        }
    }

    var chapters by remember { mutableStateOf<List<BookmarksSource.Chapter>>(emptyList()) }
    var marks by remember { mutableStateOf<List<BookmarksSource.Mark>>(emptyList()) }
    var showContents by remember { mutableStateOf(false) }
    var showMarks by remember { mutableStateOf(false) }
    var showGotoPage by remember { mutableStateOf(false) }
    var gotoInput by remember { mutableStateOf("") }
    var actionLine by remember { mutableStateOf<Int?>(null) }
    // Scroll mode renders the whole book lazily: one item per paginated page,
    // cached by index so scroll-back never re-queries the engine.
    val pageCache = remember { mutableStateMapOf<Int, PageLines>() }
    val listState = rememberLazyListState()

    // Swift paginates in pixels (Android Paint metrics), so the page box and
    // the font size are converted to px — dp would wrap every line far too early.
    val configuration = androidx.compose.ui.platform.LocalConfiguration.current
    val localDensity = androidx.compose.ui.platform.LocalDensity.current
    val density = localDensity.density
    // Text uses the full column: the chrome bars float over it as gray bands
    // when invoked, so no band is reserved while reading. The system bars are
    // hidden while the chrome is hidden (full-screen like the FBReader
    // reference), so the page starts right below the cutout.
    val cutoutTop = WindowInsets.displayCutout.asPaddingValues().calculateTopPadding()
    val contentTop = maxOf(12.dp, cutoutTop)
    val contentBottom = 12.dp
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
        // Page before pageCount: the scroll-mode effect is keyed on pageCount,
        // and it jumps the list to `page` — write the page first or the jump
        // races a recomposition and lands on item 0.
        page = opened.page
        pageCount = opened.pageCount
        val (pageLines, pagePositions, pageProgress) = ReaderSource.page(opened.page)
        lines = pageLines
        linePositions = pagePositions
        pageCache[opened.page] = PageLines(pageLines, pagePositions)
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
        if (scrollMode) {
            // The list position is the page: jump there and let the tracker
            // update the footer as the scroll settles.
            scope.launch {
                listState.scrollToItem(clamped)
                progress = if (pageCount > 1) clamped.toFloat() / (pageCount - 1) else 0f
                withContext(Dispatchers.IO) { ReaderSource.savePosition(bookId, clamped) }
            }
            return
        }
        scope.launch {
            val (pageLines, pagePositions, pageProgress) = runCatching {
                withContext(Dispatchers.IO) { ReaderSource.page(clamped) }
            }.getOrNull() ?: Triple(emptyList<String>(), emptyList<ReaderSource.LinePosition>(), 0.0)
            lines = pageLines
            linePositions = pagePositions
            pageCache[clamped] = PageLines(pageLines, pagePositions)
            progress = pageProgress.toFloat()
            withContext(Dispatchers.IO) { ReaderSource.savePosition(bookId, clamped) }
            // Neighbour pages are what the slide animation renders next;
            // loading them now keeps the turn instant instead of flashing
            // the old page mid-animation.
            for (neighbour in intArrayOf(clamped - 1, clamped + 1)) {
                if (neighbour in 0 until pageCount && pageCache[neighbour] == null) {
                    runCatching { withContext(Dispatchers.IO) { ReaderSource.page(neighbour) } }
                        .onSuccess { pageCache[neighbour] = PageLines(it.first, it.second) }
                }
            }
        }
    }

    // Scroll mode: the first visible page drives the footer and the saved
    // position, and switching into the mode lands on the page being read.
    LaunchedEffect(scrollMode, pageCount) {
        if (!scrollMode || pageCount == 0) return@LaunchedEffect
        listState.scrollToItem(page.coerceIn(0, pageCount - 1))
        snapshotFlow { listState.firstVisibleItemIndex }
            .distinctUntilChanged()
            .collect { index ->
                page = index
                progress = if (pageCount > 1) index.toFloat() / (pageCount - 1) else 0f
                clock = clockText()
            }
    }
    LaunchedEffect(scrollMode) {
        if (!scrollMode) return@LaunchedEffect
        snapshotFlow { listState.isScrollInProgress }
            .distinctUntilChanged()
            .collect { scrolling ->
                if (!scrolling) {
                    // Read the list itself: the `page` state is filled by the
                    // sibling flow and can still be one index behind here.
                    val index = listState.firstVisibleItemIndex
                    withContext(Dispatchers.IO) { ReaderSource.savePosition(bookId, index) }
                }
            }
    }

    DisposableEffect(Unit) {
        onDispose {
            // Position is saved on every page turn; the dispose hook only
            // covers a reader closed without turning a page.
            if (pageCount > 0) {
                ReaderSource.savePosition(
                    bookId,
                    if (scrollMode) listState.firstVisibleItemIndex else page,
                )
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

    // Opening a book paginates the whole text; show a loading state until the
    // first page is ready instead of a blank paper.
    if (pageCount == 0) {
        Box(
            Modifier
                .fillMaxSize()
                .background(paper.background),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                CircularProgressIndicator(color = paper.text)
                Text(stringResource(R.string.reader_loading), color = paper.secondary)
            }
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
            .pointerInput(pageCount, scrollMode) {
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
                        if (scrollMode) {
                            // The list owns the vertical offsets: find the page
                            // under the finger, then the line inside it.
                            val item = listState.layoutInfo.visibleItemsInfo.firstOrNull { info ->
                                offset.y.toInt() in info.offset..(info.offset + info.size)
                            }
                            val cached = item?.let { pageCache[it.index] }
                            if (item != null && cached != null && cached.lines.isNotEmpty()) {
                                val line = ((offset.y - item.offset) / lineHeightPx)
                                    .toInt()
                                    .coerceIn(0, cached.lines.lastIndex)
                                lines = cached.lines
                                linePositions = cached.positions
                                actionLine = line
                            }
                        } else {
                            val topPaddingPx = with(density) { contentTop.toPx() }
                            if (lineHeightPx > 0 && lines.isNotEmpty()) {
                                val index = ((offset.y - topPaddingPx) / lineHeightPx)
                                    .toInt()
                                    .coerceIn(0, lines.lastIndex)
                                actionLine = index
                            }
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
        if (scrollMode) {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    start = 20.dp,
                    end = 20.dp,
                    top = contentTop,
                    bottom = contentBottom,
                ),
            ) {
                items(pageCount) { index ->
                    val cached = pageCache[index]
                    if (cached == null) {
                        // Reserve the page's height while it loads, so the
                        // scrollbar and the current page do not jump.
                        LaunchedEffect(index) {
                            val loaded = withContext(Dispatchers.IO) {
                                runCatching { ReaderSource.page(index) }.getOrNull()
                            }
                            if (loaded != null) {
                                pageCache[index] = PageLines(loaded.first, loaded.second)
                            }
                        }
                        Spacer(Modifier.height((pageHeight / density).dp))
                    } else {
                        Column {
                            cached.lines.forEach { line ->
                                ReadLine(line, paper.text, fontSize.sp, lineHeightSp)
                            }
                        }
                    }
                }
            }
        } else {
            // Page turns slide like a book: forward pages enter from the
            // right, backward pages from the left. The cache holds the page
            // being animated to (showPage prefetches neighbours), so the
            // animation shows the right text from the first frame.
            AnimatedContent(
                targetState = page,
                modifier = Modifier.fillMaxSize(),
                transitionSpec = {
                    if (targetState > initialState) {
                        (slideInHorizontally { it } + fadeIn()) togetherWith
                            (slideOutHorizontally { -it } + fadeOut())
                    } else {
                        (slideInHorizontally { -it } + fadeIn()) togetherWith
                            (slideOutHorizontally { it } + fadeOut())
                    }
                },
                label = "page",
            ) { targetPage ->
                val pageLines = pageCache[targetPage]?.lines ?: lines
                Column(
                    Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(
                            start = 20.dp,
                            end = 20.dp,
                            top = contentTop,
                            bottom = contentBottom,
                        ),
                ) {
                    pageLines.forEach { line ->
                        ReadLine(line, paper.text, fontSize.sp, lineHeightSp)
                    }
                }
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
                    modifier = Modifier.clickable {
                        gotoInput = (page + 1).toString()
                        showGotoPage = true
                    }
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

    if (showGotoPage) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { showGotoPage = false },
            title = { Text(stringResource(R.string.reader_go_to_page)) },
            text = {
                androidx.compose.material3.OutlinedTextField(
                    value = gotoInput,
                    onValueChange = { gotoInput = it },
                    singleLine = true,
                    keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                        keyboardType = androidx.compose.ui.text.input.KeyboardType.Number
                    )
                )
            },
            confirmButton = {
                androidx.compose.material3.Button(
                    onClick = {
                        val target = gotoInput.toIntOrNull()
                        if (target != null) {
                            showPage(target - 1)
                        }
                        showGotoPage = false
                    }
                ) {
                    Text(stringResource(R.string.go))
                }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = { showGotoPage = false }) {
                    Text("Cancel")
                }
            }
        )
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
                Text(stringResource(R.string.reader_mode), fontWeight = FontWeight.Medium)
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    listOf(
                        false to R.string.reader_mode_pages,
                        true to R.string.reader_mode_scroll,
                    ).forEach { (enabled, label) ->
                        val selected = scrollMode == enabled
                        Button(
                            onClick = {
                                scrollMode = enabled
                                ReaderSettingsStore.setScrollMode(enabled)
                                showPage(page)
                            },
                            // A border is invisible on a filled button here, so the
                            // selected mode is the filled one and the other is flat.
                            colors = if (selected) {
                                ButtonDefaults.buttonColors()
                            } else {
                                ButtonDefaults.buttonColors(
                                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                                    contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            },
                        ) {
                            Text(stringResource(label))
                        }
                    }
                }
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
                                    // The cache holds lines from the previous
                                    // layout: every entry would wrap at the old
                                    // width and drift the scroll list.
                                    pageCache.clear()
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

/**
 * One engine line, drawn exactly as paginated.
 *
 * `softWrap = false` is deliberate: the engine already chose the break with the
 * same width, and letting Compose re-wrap pushed one orphan word onto a second
 * visual line, which made every page taller than the engine's estimate — the
 * scroll list then drifted and page breaks stopped lining up with the layout.
 */
@Composable
private fun ReadLine(text: String, color: Color, size: TextUnit, height: TextUnit) {
    Text(
        text = text,
        color = color,
        fontSize = size,
        fontFamily = FontFamily.Serif,
        lineHeight = height,
        softWrap = false,
        overflow = TextOverflow.Visible,
        modifier = Modifier.fillMaxWidth(),
    )
}
