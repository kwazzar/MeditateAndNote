package com.mn.android.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Contract for the note-insights read: Kotlin decodes what the domain
 * analyzer produced, and the rules themselves stay in Core.
 *
 * The notes are written through `NoteEditorSource.save`, so the store holds
 * the real Swift-encoded note payloads the app writes — not hand-made JSON.
 */
@RunWith(AndroidJUnit4::class)
class NoteInsightsContractTest {

    private val originalTransport = AIDraftProvider.transport

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        NoteBlobStore.configure(context)
        NoteBlobStore.deleteAll()
        NoteInsightBlobStore.configure(context)
        NoteInsightBlobStore.deleteAll()
        AIDraftSettingsStore.configure(context)
        AIDraftSettingsStore.save("http://10.0.2.2:8731/v1/chat/completions", "mock-model", "test-key")
    }

    @After
    fun tearDown() {
        AIDraftProvider.transport = originalTransport
    }

    @Test
    fun load_returnsInsights_whenNotesHaveContent() {
        val id = UUID.randomUUID().toString()
        NoteEditorSource.save(
            id = id,
            title = "Evening",
            content = "calm breathing practice for anxiety before sleep",
        )

        val insights = NoteInsightsSource.load()

        assertTrue("expected at least one insight", insights.isNotEmpty())
        val insight = insights.first()
        // Swift renders a UUID in upper case, Kotlin in lower case.
        assertEquals(id.uppercase(), insight.id)
        assertTrue("summary should not be empty", insight.summary.isNotEmpty())
        assertTrue("expected a 'calm' tag", insight.tags.contains("calm"))
        assertTrue(
            "expected a 'calm' theme",
            insight.themes.any { it.label == "calm" },
        )
    }

    @Test
    fun load_returnsEmptyList_whenThereAreNoNotes() {
        val insights = NoteInsightsSource.load()

        assertTrue("expected no insights", insights.isEmpty())
    }

    @Test
    fun topThemes_ranksTheMostFrequentLabelsFirst() {
        val insights = listOf(
            NoteInsightsSource.Insight(
                id = "1",
                summary = "a",
                tags = listOf("calm"),
                themes = listOf(
                    NoteInsightsSource.Theme("calm", 1.0),
                    NoteInsightsSource.Theme("sleep", 0.5),
                ),
            ),
            NoteInsightsSource.Insight(
                id = "2",
                summary = "b",
                tags = listOf("calm"),
                themes = listOf(NoteInsightsSource.Theme("calm", 0.8)),
            ),
        )

        val themes = NoteInsightsSource.topThemes(insights)

        assertEquals(listOf("calm", "sleep"), themes)
    }

    @Test
    fun stored_returnsEmptyList_whenNothingWasAnalyzed() {
        assertTrue(
            "expected no stored insights",
            NoteInsightsSource.storedInsights().isEmpty(),
        )
    }

    @Test
    fun analyze_usesTheProviderAnswer() {
        val id = UUID.randomUUID().toString()
        NoteEditorSource.save(id = id, title = "Evening", content = "calm breathing practice")
        AIDraftProvider.transport = { _, body -> providerAnswer(body) }

        val analysis = NoteInsightsSource.analyzeInsights()

        assertEquals("llm", analysis.source)
        assertTrue("expected insights", analysis.insights.isNotEmpty())
        val insight = analysis.insights.first()
        assertEquals("A quiet morning walk", insight.summary)
        assertEquals(listOf("clarity", "calm"), insight.tags)
        assertEquals(listOf("clarity", "calm"), insight.themes.map { it.label })
    }

    @Test
    fun analyze_fallsBackToTheHeuristic_whenTheProviderFails() {
        NoteEditorSource.save(
            id = UUID.randomUUID().toString(),
            title = "Evening",
            content = "calm breathing practice for anxiety before sleep",
        )
        AIDraftProvider.transport = { _, _ -> throw IllegalStateException("no network") }

        val analysis = NoteInsightsSource.analyzeInsights()

        assertEquals("heuristic", analysis.source)
        assertTrue("expected insights", analysis.insights.isNotEmpty())
        assertTrue(
            "expected a 'calm' theme",
            analysis.insights.first().themes.any { it.label == "calm" },
        )
    }

    @Test
    fun analyze_storesTheInsights_soTheySurviveARestart() {
        NoteEditorSource.save(
            id = UUID.randomUUID().toString(),
            title = "Evening",
            content = "calm breathing practice",
        )
        AIDraftProvider.transport = { _, body -> providerAnswer(body) }

        val analysis = NoteInsightsSource.analyzeInsights()
        val stored = NoteInsightsSource.storedInsights()

        assertEquals(analysis.insights.size, stored.size)
        assertEquals(
            analysis.insights.map { it.summary }.toSet(),
            stored.map { it.summary }.toSet(),
        )
    }

    /**
     * A chat-completions answer that echoes the note id out of the prompt,
     * so the insight is bound to a note the app really has.
     */
    private fun providerAnswer(body: String): AIDraftProvider.TransportResult {
        val noteId = Regex("NOTE ([0-9A-Fa-f-]{36}):").find(body)?.groupValues?.get(1).orEmpty()
        val content = JSONObject().apply {
            put(
                "insights",
                JSONArray().apply {
                    put(
                        JSONObject().apply {
                            put("noteID", noteId)
                            put("themes", JSONArray().apply { put("clarity"); put("calm") })
                            put("summary", "A quiet morning walk")
                            put("tags", JSONArray().apply { put("clarity"); put("calm") })
                        },
                    )
                },
            )
        }.toString()
        val envelope = JSONObject().apply {
            put(
                "choices",
                JSONArray().apply {
                    put(
                        JSONObject().apply {
                            put("message", JSONObject().apply { put("content", content) })
                        },
                    )
                },
            )
        }.toString()
        return AIDraftProvider.TransportResult(ok = true, status = 200, body = envelope)
    }
}
