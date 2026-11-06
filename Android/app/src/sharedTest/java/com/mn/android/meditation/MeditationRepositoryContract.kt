package com.mn.android.meditation

import com.mn.android.domain.meditation.CompletedSession
import com.mn.android.domain.meditation.MeditationId
import com.mn.android.domain.meditation.MeditationRepository
import com.mn.android.domain.meditation.model.MeditationUi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

abstract class MeditationRepositoryContract {
    protected abstract fun createRepo(): MeditationRepository

    @Test fun catalogNotEmpty() = runTest {
        val repo = createRepo()
        val catalog: List<MeditationUi> = repo.catalog
        assertNotNull(catalog)
        assertTrue(catalog.isNotEmpty())
        catalog.forEach { m ->
            assertNotNull(m.id)
            assertTrue(m.title.isNotEmpty())
        }
    }

    @Test fun recordSessionPersists() = runTest {
        val repo = createRepo()
        val session = CompletedSession(
            meditationId = MeditationId("test-meditation"),
            durationSeconds = 300,
            dateMillis = System.currentTimeMillis(),
            tzOffsetMinutes = 0
        )
        val result = repo.recordSession(session)
        assertTrue(result.isSuccess)
    }
}
