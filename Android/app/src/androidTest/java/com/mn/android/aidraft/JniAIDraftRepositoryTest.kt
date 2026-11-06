package com.mn.android.aidraft

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.mn.android.application.subscription.EntitlementSource
import com.mn.android.application.subscription.SubscriptionScope
import com.mn.android.data.AIDraftProvider
import com.mn.android.data.AIDraftQuotaCounter
import com.mn.android.data.AIDraftSessionStorage
import com.mn.android.data.AIDraftSettingsStore
import com.mn.android.data.aidraft.JniAIDraftRepository
import com.mn.android.domain.aidraft.AIDraftError
import com.mn.android.domain.aidraft.AIDraftMetric
import com.mn.android.domain.aidraft.AIDraftRepository
import com.mn.android.domain.note.NoteId
import com.mn.android.infrastructure.persistence.local.ai.AIDraftMetrics
import com.mn.android.infrastructure.persistence.local.ai.MeditateDatabase
import java.util.UUID
import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The AI draft path over the JNI bridge.
 *
 * The provider is replaced by a stub: a test process on Android cannot host
 * an HTTP server to answer a POST. Everything else is the real path - the
 * session state machine, the quota rule and the parsing of the model's answer
 * all live in Core and run for real.
 */
@RunWith(AndroidJUnit4::class)
class JniAIDraftRepositoryTest : AIDraftRepositoryContract() {

    private val originalTransport = AIDraftProvider.transport

    private companion object {
        const val FREE_LIMIT = 5
    }

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        AIDraftSettingsStore.configure(context)
        AIDraftQuotaCounter.configure(context)
        AIDraftMetrics.configure(context)
        AIDraftSessionStorage.configure(context)
        AIDraftQuotaCounter.reset()
        // The endpoint the manual QA run uses (the emulator reaches the host
        // machine as 10.0.2.2); the tests fake the transport anyway.
        AIDraftSettingsStore.save("http://10.0.2.2:8731/v1/chat/completions", "mock-model", "test-key")
        AIDraftProvider.transport = { _, _ -> providerResponse() }
    }

    @After
    fun tearDown() {
        AIDraftProvider.transport = originalTransport
        AIDraftQuotaCounter.reset()
        // A pro entitlement from the quota test must not leak into the next
        // one - the free allowance has to start from zero again.
        SubscriptionScope.reset(InstrumentationRegistry.getInstrumentation().targetContext)
    }

    override fun createRepo(): AIDraftRepository = JniAIDraftRepository()

    @Test
    fun start_failsWithFreeQuotaExhausted_afterTheFreeAllowance() = runBlocking {
        val repo = createRepo()
        // AIDraftQuota.freeLimit - the constant lives in Core and is not
        // exported to Java, so the test states it here on purpose: a change
        // to the product value has to break this test.
        repeat(FREE_LIMIT) {
            val result = repo.start(NoteId(UUID.randomUUID().toString()), "", "a calm morning")
            assertTrue(result.error?.toString() ?: "", result.ok)
        }

        val result = repo.start(NoteId(UUID.randomUUID().toString()), "", "a calm morning")

        assertFalse(result.ok)
        assertTrue(
            "the quota has to be named",
            result.error is AIDraftError.FreeQuotaExhausted,
        )
    }

    @Test
    fun start_succeeds_afterTheFreeAllowance_whenTheUserIsPro() = runBlocking {
        // The rule stays in Core (`AIDraftQuota.allowsDraft`); the entitlement
        // is Kotlin's state and reaches the bridge through
        // `EntitlementSource` - the same division of labour as the counter.
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        EntitlementSource.configure(context)
        val manager = SubscriptionScope.manager(context)
        val product = manager.offerings().first().packages.first()
        manager.purchase(product)
        val repo = createRepo()

        repeat(FREE_LIMIT) {
            val result = repo.start(NoteId(UUID.randomUUID().toString()), "", "a calm morning")
            assertTrue(result.error?.toString() ?: "", result.ok)
        }

        // The allowance is used up, but a pro user is not limited.
        val result = repo.start(NoteId(UUID.randomUUID().toString()), "", "a calm morning")

        assertTrue(result.error?.toString() ?: "", result.ok)
        assertNull(result.error)
    }

    @Test
    fun start_failsWithProviderUnavailable_whenTheProviderFails() = runBlocking {
        AIDraftProvider.transport = { _, _ ->
            AIDraftProvider.TransportResult(ok = false, status = 500, body = "")
        }
        val repo = createRepo()

        val result = repo.start(NoteId(UUID.randomUUID().toString()), "", "a calm morning")

        assertFalse(result.ok)
        assertEquals("providerUnavailable", (result.error as AIDraftError.Failed).kind)
    }

    @Test
    fun start_reportsTheGenerationMetric() = runBlocking {
        val repo = createRepo()

        val result = repo.start(NoteId(UUID.randomUUID().toString()), "", "a calm morning")

        val metric = result.metric
        assertNotNull(metric)
        assertEquals("generationCompleted", metric!!.kind)
        assertEquals(1L, metric.suggestionCount)
        assertNotNull(metric.latencyMs)
    }

    @Test
    fun metrics_areWrittenToTheDatabase() = runBlocking {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val dao = MeditateDatabase.get(context).aiDraftMetricDao()
        dao.deleteAll()

        AIDraftMetrics.record(
            AIDraftMetric(kind = "generationCompleted", latencyMs = 12, suggestionCount = 2),
        )

        val rows = dao.fetchAll()
        assertEquals(1, rows.size)
        assertEquals("generationCompleted", rows.first().kind)
        assertEquals(12L, rows.first().latencyMs)
    }

    /** A chat-completions answer with one suggestion. */
    private fun providerResponse(): AIDraftProvider.TransportResult {
        val content = JSONObject()
            .put("suggestions", JSONArray().put(
                JSONObject().put("text", "Keep walking slowly").put("rationale", "matches the calm tone"),
            ))
            .toString()
        val body = JSONObject()
            .put("choices", JSONArray().put(
                JSONObject().put("message", JSONObject().put("content", content)),
            ))
            .toString()
        return AIDraftProvider.TransportResult(ok = true, status = 200, body = body)
    }
}
