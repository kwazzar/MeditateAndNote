package com.mn.android.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Contract for the AI draft commands.
 *
 * The provider is replaced by a stub: a test process on Android cannot host
 * an HTTP server to answer a POST. Everything else is the real path - the
 * domain session, the quota rule and the parsing of the model's answer all
 * live in Core and run for real.
 */
@RunWith(AndroidJUnit4::class)
class AIDraftContractTest {

    private val originalTransport = AIDraftProvider.transport

    private companion object {
        const val FREE_LIMIT = 5
    }

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        AIDraftSettingsStore.configure(context)
        AIDraftQuotaCounter.configure(context)
        AIDraftQuotaCounter.reset()
        AIDraftSettingsStore.save("", "", "test-key")
        AIDraftProvider.transport = { _, _ -> providerResponse() }
    }

    @After
    fun tearDown() {
        AIDraftProvider.transport = originalTransport
        AIDraftQuotaCounter.reset()
    }

    @Test
    fun start_returnsSuggestions_whenTheProviderAnswers() {
        val result = AIDraftSource.start(
            noteId = UUID.randomUUID().toString(),
            instruction = "",
            context = "I walked by the river and felt calm",
        )

        assertTrue(result.error ?: "", result.ok)
        val session = result.session
        assertNotNull(session)
        assertEquals("ready", session!!.state)
        assertTrue(session.grounded)
        assertEquals(1, session.suggestions.size)
        assertEquals("Keep walking slowly", session.suggestions.first().text)
        assertEquals(1, session.pending.size)
    }

    @Test
    fun start_asksQuestions_whenThereIsNoContext() {
        val result = AIDraftSource.start(
            noteId = UUID.randomUUID().toString(),
            instruction = "",
            context = "",
        )

        assertTrue(result.error ?: "", result.ok)
        assertFalse(result.session!!.grounded)
    }

    @Test
    fun accept_movesTheSuggestionIntoTheAcceptedPool() {
        val started = AIDraftSource.start(UUID.randomUUID().toString(), "", "a calm morning")
        val document = started.document!!
        val suggestionId = started.session!!.suggestions.first().id

        val accepted = AIDraftSource.accept(document, suggestionId)

        assertTrue(accepted.error ?: "", accepted.ok)
        assertEquals(1, accepted.session!!.accepted.size)
        assertEquals(0, accepted.session!!.pending.size)
    }

    @Test
    fun reject_sendsAnAcceptedSuggestionBackToPending() {
        val started = AIDraftSource.start(UUID.randomUUID().toString(), "", "a calm morning")
        val suggestionId = started.session!!.suggestions.first().id
        val accepted = AIDraftSource.accept(started.document!!, suggestionId)

        val rejected = AIDraftSource.reject(accepted.document!!, suggestionId)

        assertTrue(rejected.error ?: "", rejected.ok)
        assertEquals(0, rejected.session!!.accepted.size)
        assertEquals(1, rejected.session!!.pending.size)
    }

    @Test
    fun acceptAll_acceptsEveryPendingSuggestion() {
        val started = AIDraftSource.start(UUID.randomUUID().toString(), "", "a calm morning")

        val accepted = AIDraftSource.acceptAllPending(started.document!!)

        assertTrue(accepted.error ?: "", accepted.ok)
        assertEquals(accepted.session!!.suggestions.size, accepted.session!!.accepted.size)
    }

    @Test
    fun start_failsWithFreeQuotaExhausted_afterTheFreeAllowance() {
        // AIDraftQuota.freeLimit - the constant lives in Core and is not
        // exported to Java, so the test states it here on purpose: a change
        // to the product value has to break this test.
        repeat(FREE_LIMIT) {
            val result = AIDraftSource.start(UUID.randomUUID().toString(), "", "a calm morning")
            assertTrue(result.error ?: "", result.ok)
        }

        val result = AIDraftSource.start(UUID.randomUUID().toString(), "", "a calm morning")

        assertFalse(result.ok)
        assertEquals("freeQuotaExhausted", result.error)
    }

    @Test
    fun start_failsWithProviderUnavailable_whenTheProviderFails() {
        AIDraftProvider.transport = { _, _ ->
            AIDraftProvider.TransportResult(ok = false, status = 500, body = "")
        }

        val result = AIDraftSource.start(UUID.randomUUID().toString(), "", "a calm morning")

        assertFalse(result.ok)
        assertEquals("providerUnavailable", result.error)
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
