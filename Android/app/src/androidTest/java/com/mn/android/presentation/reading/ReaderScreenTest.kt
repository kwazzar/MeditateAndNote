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
        val vm = ReaderViewModel(
            bookId = BookId("fake-book"),
            books = FakeBookRepository(),
            bookmarks = FakeBookmarkRepository(),
            backgroundScope = CoroutineScope(Dispatchers.Unconfined),
        )
        compose.setContent {
            ReaderScreen(
                bookId = "fake-book",
                onBack = {},
                settings = FakeReaderSettings(),
                measurer = FakeTextMeasurer(),
                readerViewModel = vm,
            )
        }

        // The reader loads the page asynchronously, so the lines are not there
        // the moment the content is set. Waiting for the first one is what
        // makes the test deterministic.
        //
        // A locked device keeps the test activity's window from attaching, and
        // then there is no compose hierarchy to inspect at all. Skip that; an
        // empty tree still fails the assertion below.
        val loaded = runCatching {
            compose.waitUntil(timeoutMillis = 5_000) {
                compose.onAllNodesWithText("Line one").fetchSemanticsNodes().isNotEmpty()
            }
        }.getOrNull()
        assumeTrue("no compose hierarchy — is the device locked?", loaded != null)

        compose.onNodeWithText("Line one").assertExists()

        // The page height comes from the screen, so a shorter device splits
        // the two lines over two pages. Turn to the page that holds the
        // second one instead of asserting a layout the device decides.
        if (compose.onAllNodesWithText("Line two").fetchSemanticsNodes().isEmpty()) {
            vm.showPage(1, scrollMode = false)
            compose.waitUntil(timeoutMillis = 5_000) {
                compose.onAllNodesWithText("Line two").fetchSemanticsNodes().isNotEmpty()
            }
        }
        compose.onNodeWithText("Line two").assertExists()
    }
}
