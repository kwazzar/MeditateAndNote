package com.mn.android.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.util.UUID
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

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        NoteBlobStore.configure(context)
        NoteBlobStore.deleteAll()
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
}
