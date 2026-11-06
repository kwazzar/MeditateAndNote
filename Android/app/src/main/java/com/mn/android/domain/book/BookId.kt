package com.mn.android.domain.book

/** A book's identity. Swift's `BookID` is a UUID; the wire form is its string. */
@JvmInline
value class BookId(val value: String)
