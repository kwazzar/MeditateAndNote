package com.mn.android.book

import com.mn.android.domain.book.BookRepository

class FakeBookRepositoryTest : BookRepositoryContract() {
    override fun createRepo(): BookRepository = FakeBookRepository()
}
