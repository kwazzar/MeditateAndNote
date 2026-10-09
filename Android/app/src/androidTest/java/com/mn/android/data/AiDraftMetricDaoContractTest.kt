package com.mn.android.data

import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AiDraftMetricDaoContractTest {

    private lateinit var db: MeditateDatabase
    private lateinit var aiDraftMetricDao: AiDraftMetricDao

    @Before
    fun setup() {
        val appContext = InstrumentationRegistry.getInstrumentation().targetContext
        db = Room.inMemoryDatabaseBuilder(appContext, MeditateDatabase::class.java).build()
        aiDraftMetricDao = db.aiDraftMetricDao()
    }

    @After
    fun tearDown() {
        db.close()
    }

    @Test
    fun insertAndGetAiDraftMetric() = runBlocking {
        val aiDraftMetric = AiDraftMetricEntity(
            id = 1L,
            kind = "GenerationStarted",
            warmCold = true
        )

        aiDraftMetricDao.insert(aiDraftMetric)

        val inserted = aiDraftMetricDao.fetchAll().firstOrNull { it.kind == "GenerationStarted" }
        assertNotNull(inserted)
        assertEquals(aiDraftMetric.kind, inserted?.kind)
        assertEquals(aiDraftMetric.warmCold, inserted?.warmCold)
    }

    @Test
    fun fetchAll_returnsAllInsertedMetrics() = runBlocking {
        val metric1 = AiDraftMetricEntity(kind = "GenerationStarted", warmCold = true)
        val metric2 = AiDraftMetricEntity(kind = "GenerationCompleted", latencyMs = 100L, suggestionCount = 5L)

        aiDraftMetricDao.insert(metric1)
        aiDraftMetricDao.insert(metric2)

        val all = aiDraftMetricDao.fetchAll()
        assertEquals(2, all.size)
    }

    @Test
    fun deleteAll_clearsAllMetrics() = runBlocking {
        aiDraftMetricDao.insert(AiDraftMetricEntity(kind = "GenerationStarted", warmCold = true))
        aiDraftMetricDao.insert(AiDraftMetricEntity(kind = "GenerationCompleted", latencyMs = 100L))

        aiDraftMetricDao.deleteAll()

        assertEquals(0, aiDraftMetricDao.fetchAll().size)
    }
}