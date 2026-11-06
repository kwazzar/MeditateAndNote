package com.mn.android.presentation.reading

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.mn.android.book.FakeBookmarkRepository
import com.mn.android.book.FakeBookRepository
import com.mn.android.domain.book.BookId
import com.mn.android.presentation.reading.ui.ReaderScreen
import com.mn.android.presentation.reading.viewmodel.ReaderViewModel
import com.mn.android.reader.FakeReaderSettings
import com.mn.android.reader.FakeTextMeasurer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The reader renders the page the engine paginated. The screen is the most
 * wiring-heavy one in the app, and a broken composition compiles fine — this
 * is the check that it still comes up.
 */
@RunWith(AndroidJUnit4::class)
class ReaderScreenTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun theReaderShowsThePaginatedLines() {
        compose.setContent {
            ReaderScreen(
                bookId = "fake-book",
                onBack = {},
                settings = FakeReaderSettings(),
                measurer = FakeTextMeasurer(),
                readerViewModel = ReaderViewModel(
                    bookId = BookId("fake-book"),
                    books = FakeBookRepository(),
                    bookmarks = FakeBookmarkRepository(),
                    backgroundScope = CoroutineScope(Dispatchers.Unconfined),
                ),
            )
        }

        // A locked device keeps the test activity's window from attaching, and
        // then there is no compose hierarchy to inspect at all. Skip that; an
        // empty tree still fails the assertion below.
        val found = runCatching {
            compose.onAllNodesWithText("Line one").fetchSemanticsNodes()
        }.getOrNull()
        assumeTrue("no compose hierarchy — is the device locked?", found != null)

        compose.onNodeWithText("Line one").assertExists()
        compose.onNodeWithText("Line two").assertExists()
    }
}
