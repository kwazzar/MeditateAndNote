package com.mn.android.presentation.reading.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.FormatSize
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
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.R
import com.mn.android.data.ReaderSettingsStore
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

@OptIn(ExperimentalMaterial3Api::class)
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
    var showChrome by remember { mutableStateOf(true) }

    var title by remember { mutableStateOf("") }
    var pageCount by remember { mutableIntStateOf(0) }
    var page by remember { mutableIntStateOf(0) }
    var lines by remember { mutableStateOf<List<String>>(emptyList()) }
    var progress by remember { mutableFloatStateOf(0f) }
    var loadFailed by remember { mutableStateOf(false) }

    // Swift paginates in pixels (Android Paint metrics), so the page box and
    // the font size are converted to px — dp would wrap every line far too early.
    val configuration = androidx.compose.ui.platform.LocalConfiguration.current
    val density = androidx.compose.ui.platform.LocalDensity.current.density
    val pageWidth = (configuration.screenWidthDp - 40.0) * density
    val pageHeight = (configuration.screenHeightDp - 140.0) * density
    val fontSizePx = fontSize * density

    suspend fun openBook() = withContext(Dispatchers.IO) {
        val opened = ReaderSource.open(bookId, fontSizePx.toDouble(), pageWidth, pageHeight)
        title = opened.title
        pageCount = opened.pageCount
        page = opened.page
        val (pageLines, pageProgress) = ReaderSource.page(opened.page)
        lines = pageLines
        progress = pageProgress.toFloat()
    }

    LaunchedEffect(bookId) {
        runCatching { openBook() }.onFailure {
            android.util.Log.e("ReaderScreen", "open failed", it)
            loadFailed = true
        }
    }

    fun showPage(index: Int) {
        val clamped = index.coerceIn(0, (pageCount - 1).coerceAtLeast(0))
        page = clamped
        scope.launch {
            val (pageLines, pageProgress) = runCatching {
                withContext(Dispatchers.IO) { ReaderSource.page(clamped) }
            }.getOrNull() ?: (emptyList<String>() to 0.0)
            lines = pageLines
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
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 56.dp),
        ) {
            lines.forEach { line ->
                Text(
                    line,
                    color = paper.text,
                    fontSize = fontSize.sp,
                    fontFamily = FontFamily.Serif,
                    lineHeight = (fontSize * 1.45f).sp,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }

        // Tap zones over the page: left = back, center = chrome, right = forward.
        // The top and bottom bars are excluded so their buttons stay clickable.
        Box(
            Modifier
                .fillMaxSize()
                .padding(top = 56.dp, bottom = 56.dp)
                .pointerInput(pageCount) {
                    detectTapGestures { offset ->
                        val third = size.width / 3f
                        when {
                            offset.x < third -> showPage(page - 1)
                            offset.x > third * 2 -> showPage(page + 1)
                            else -> showChrome = !showChrome
                        }
                    }
                }
        )

        if (showChrome) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 8.dp, vertical = 4.dp)
                    .align(Alignment.TopCenter),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = stringResource(R.string.back),
                        tint = paper.text,
                    )
                }
                Spacer(Modifier.weight(1f))
                IconButton(onClick = { showSettings = true }) {
                    Icon(
                        Icons.Filled.FormatSize,
                        contentDescription = stringResource(R.string.reader_font_size),
                        tint = paper.text,
                    )
                }
            }
            Row(
                Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(16.dp)
                    .align(Alignment.BottomCenter),
            ) {
                Text(
                    stringResource(R.string.reader_page_format, page + 1, pageCount),
                    color = paper.secondary,
                    style = MaterialTheme.typography.labelMedium,
                )
                Spacer(Modifier.weight(1f))
                Text(
                    stringResource(R.string.percent_format, (progress * 100).toInt()),
                    color = paper.secondary,
                    style = MaterialTheme.typography.labelMedium,
                )
            }
        }
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
                                        ReaderSource.repaginate(bookId, fontSizePx.toDouble(), pageWidth, pageHeight)
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
                        Button(
                            onClick = {
                                paper = candidate
                                ReaderSettingsStore.setPaper(candidate.name)
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
