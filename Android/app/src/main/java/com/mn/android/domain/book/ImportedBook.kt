package com.mn.android.domain.book

/** The result of an import: the new book and the format it came in as. */
data class ImportedBook(val id: BookId, val format: String)
