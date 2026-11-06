package com.mn.android.domain.note

/**
 * One note in the list.
 *
 * The content is the note's own text, not a preview: the search looks into
 * the whole note, like the iOS list does. How much of it the card shows is
 * the card's business.
 */
data class NoteListItem(
    val id: NoteId,
    val title: String,
    val content: String,
    val dateMillis: Long
)
