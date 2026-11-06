package com.mn.android.meditation

import com.mn.android.domain.meditation.CompletedSession
import com.mn.android.domain.meditation.MeditationRepository
import com.mn.android.domain.meditation.model.MeditationUi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

class FakeMeditationRepository : MeditationRepository {

    private val _catalog = MutableStateFlow<List<MeditationUi>>(listOf(
        MeditationUi("test-1", "Test Meditation 1", "box", null, "breathing", "box"),
        MeditationUi("test-2", "Test Meditation 2", "4-7-8", null, "breathing", "4-7-8")
    ))

    private val _sessions = MutableStateFlow<List<CompletedSession>>(emptyList())

    override val catalog: List<MeditationUi>
        get() = _catalog.value

    override suspend fun recordSession(session: CompletedSession): Result<Unit> {
        _sessions.update { it + session }
        return Result.success(Unit)
    }
}
