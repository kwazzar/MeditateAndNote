package com.mn.android.domain.book

/** A mark's identity. Swift's `BookmarkID` is a UUID; the wire form is its string. */
@JvmInline
value class BookmarkId(val value: String)
