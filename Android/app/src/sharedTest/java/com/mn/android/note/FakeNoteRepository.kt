package com.mn.android.note

import com.mn.android.domain.note.NoteDetail
import com.mn.android.domain.note.NoteDraft
import com.mn.android.domain.note.NoteId
import com.mn.android.domain.note.NoteListItem
import com.mn.android.domain.note.NoteRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import java.util.UUID

class FakeNoteRepository(
    private val clock: () -> Long = { System.currentTimeMillis() },
    private val idGenerator: () -> String = { UUID.randomUUID().toString() }
) : NoteRepository {

    private val state = MutableStateFlow<Map<NoteId, NoteDetail>>(emptyMap())

    override fun newId(): NoteId = NoteId(idGenerator())

    override suspend fun save(id: NoteId, draft: NoteDraft): Result<NoteDetail> {
        val detail = NoteDetail(id, draft.title, draft.content, clock())
        state.update { it + (id to detail) }
        return Result.success(detail)
    }

    override suspend fun delete(id: NoteId): Result<Unit> {
        state.update { it - id }
        return Result.success(Unit)
    }

    override suspend fun get(id: NoteId): Result<NoteDetail?> = Result.success(state.value[id])

    override fun observe(): Flow<List<NoteListItem>> =
        state.map { it.values.map(NoteDetail::toListItem) }
}
