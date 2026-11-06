package com.mn.android.data.meditation

import com.mn.android.data.SessionRecorder
import com.mn.android.data.ioResult
import com.mn.android.domain.meditation.CompletedSession
import com.mn.android.domain.meditation.MeditationError
import com.mn.android.domain.meditation.MeditationRepository
import com.mn.android.domain.meditation.model.MeditationUi
import com.mn.android.infrastructure.persistence.local.meditation.MeditationCatalog

class JniMeditationRepository(
    private val catalogSource: MeditationCatalog = MeditationCatalog,
    private val recorder: SessionRecorder = SessionRecorder
) : MeditationRepository {

    override val catalog: List<MeditationUi>
        get() = catalogSource.load()

    override suspend fun recordSession(session: CompletedSession): Result<Unit> = ioResult(
        { MeditationError.RecordFailed(it) }
    ) {
        val saved = recorder.record(
            session.meditationId.value,
            session.durationSeconds.toDouble(),
            session.tzOffsetMinutes
        )
        if (saved != 1L) throw IllegalStateException("session not persisted (saved=$saved)")
    }
}
