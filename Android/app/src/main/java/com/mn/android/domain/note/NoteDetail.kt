package com.mn.android.domain.note

data class NoteDetail(
    val id: NoteId,
    val title: String,
    val content: String,
    val dateMillis: Long
) {
    fun toListItem(): NoteListItem =
        NoteListItem(id, title, content, dateMillis)
}