package com.mn.android.book

import com.mn.android.domain.book.BookId
import com.mn.android.domain.book.BookmarkRepository

class FakeBookmarkRepositoryTest : BookmarkRepositoryContract() {
    override fun createRepo(): BookmarkRepository = FakeBookmarkRepository()
    override fun bookId(): BookId = BookId("fake-book")
}
