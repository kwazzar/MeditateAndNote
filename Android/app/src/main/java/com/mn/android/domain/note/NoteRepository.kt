package com.mn.android.domain.note

import kotlinx.coroutines.flow.Flow

interface NoteRepository {
    fun newId(): NoteId
    /** Answers with the note as it was stored — the title comes back normalised. */
    suspend fun save(id: NoteId, draft: NoteDraft): Result<NoteDetail>
    suspend fun delete(id: NoteId): Result<Unit>
    suspend fun get(id: NoteId): Result<NoteDetail?>
    fun observe(): Flow<List<NoteListItem>>
}