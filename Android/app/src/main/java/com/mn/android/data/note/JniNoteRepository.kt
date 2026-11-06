package com.mn.android.data.note

import com.mn.android.data.NoteEditorSource
import com.mn.android.data.NoteMenuSource
import com.mn.android.data.ioResult
import com.mn.android.domain.events.DomainEvent
import com.mn.android.domain.events.DomainEventBus
import com.mn.android.domain.note.NoteDetail
import com.mn.android.domain.note.NoteDraft
import com.mn.android.domain.note.NoteError
import com.mn.android.domain.note.NoteId
import com.mn.android.domain.note.NoteListItem
import com.mn.android.domain.note.NoteRepository
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.TimeZone
import java.util.UUID

class JniNoteRepository(
    private val editor: NoteEditorSource,
    private val menu: NoteMenuSource,
    private val bus: DomainEventBus = DomainEventBus,
    private val idGenerator: () -> String = { UUID.randomUUID().toString() },
    private val tzOffsetProvider: () -> Int = { TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 60_000 }
) : NoteRepository {

    override fun newId(): NoteId = NoteId(idGenerator())

    override suspend fun save(id: NoteId, draft: NoteDraft): Result<NoteDetail> = ioResult(
        { NoteError.SaveFailed(it) }
    ) {
        // The store does not say whether it created or replaced the row, and
        // analytics tell the two apart, so the id is looked up first.
        val existed = editor.loadNote(id.value) != null
        val normalizedTitle = editor.saveWithOffset(id.value, draft.title, draft.content, tzOffsetProvider())
        if (normalizedTitle.isEmpty()) throw IllegalStateException("save returned empty title")
        bus.publish(
            if (existed) DomainEvent.NoteUpdated(id.value) else DomainEvent.NoteCreated(id.value)
        )
        // The stored note comes back, so the editor shows the title the
        // domain normalised rather than the one that was typed.
        editor.loadNote(id.value)?.let { note ->
            NoteDetail(canonical(note.id), note.title, note.content, note.dateMillis)
        } ?: throw IllegalStateException("the note vanished right after the save")
    }

    override suspend fun delete(id: NoteId): Result<Unit> = ioResult(
        { NoteError.DeleteFailed(it) }
    ) {
        editor.delete(id.value)
        bus.publish(DomainEvent.NoteDeleted(id.value))
    }

    override suspend fun get(id: NoteId): Result<NoteDetail?> = ioResult(
        { NoteError.LoadFailed(it) }
    ) {
        editor.loadNote(id.value)?.let { note ->
            NoteDetail(canonical(note.id), note.title, note.content, note.dateMillis)
        }
    }

    /**
     * The list, re-read whenever a note changes.
     *
     * The bus subscription is established before the first read, so a mutation
     * that lands in between still triggers a reload. That is why this is a
     * plain `flow` and not a `channelFlow` with `flowOn`: `flowOn` collects the
     * upstream in another coroutine, which leaves a window where the
     * subscription does not exist yet and the event is dropped.
     */
    override fun observe(): Flow<List<NoteListItem>> = flow {
        coroutineScope {
            val refresh = Channel<Unit>(Channel.CONFLATED)
            val subscription = launch(start = CoroutineStart.UNDISPATCHED) {
                bus.events
                    .filter { it is DomainEvent.NoteCreated || it is DomainEvent.NoteUpdated || it is DomainEvent.NoteDeleted }
                    .collect { refresh.trySend(Unit) }
            }
            refresh.trySend(Unit)
            try {
                for (signal in refresh) {
                    emit(withContext(Dispatchers.IO) { menu.readMenu().notes.map(::toListItem) })
                }
            } finally {
                subscription.cancel()
                refresh.close()
            }
        }
    }

    private fun toListItem(r: NoteMenuSource.NoteRecord): NoteListItem =
        NoteListItem(canonical(r.id), r.title, r.content, r.dateMillis)

    /**
     * One id, one spelling. Swift hands ids back as `UUID.uuidString`, which
     * is UPPERCASE, while Kotlin's `UUID.toString()` is lowercase — so the id
     * a note is saved under would never equal the id the list shows. The
     * canonical form is lowercase (RFC 4122); Swift's `UUID(uuidString:)`
     * accepts both, so the store needs no change.
     */
    private fun canonical(id: String): NoteId = NoteId(id.lowercase())
}
