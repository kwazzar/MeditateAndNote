package com.mn.android.domain.meditation

import com.mn.android.domain.meditation.model.MeditationUi

interface MeditationRepository {
    /** The catalog from Swift Core, flattened for the UI. */
    val catalog: List<MeditationUi>

    /** Records a completed meditation session. */
    suspend fun recordSession(session: CompletedSession): Result<Unit>
}
