package com.mn.android.meditation

import com.mn.android.data.SessionRecorder
import com.mn.android.infrastructure.persistence.local.meditation.MeditationCatalog

class JniMeditationRepositoryTest : MeditationRepositoryContract() {
    override fun createRepo() = com.mn.android.data.meditation.JniMeditationRepository(
        catalogSource = MeditationCatalog,
        recorder = SessionRecorder
    )
}