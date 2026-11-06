package com.mn.android.insights

import com.mn.android.domain.insights.NoteInsight
import com.mn.android.domain.insights.NoteInsightTheme
import com.mn.android.domain.insights.NoteInsightsAnalysis
import com.mn.android.domain.insights.NoteInsightsRepository

/** The in-memory insights: what the tests and the previews read. */
class FakeNoteInsightsRepository : NoteInsightsRepository {

    var insights: List<NoteInsight> = listOf(
        NoteInsight(
            id = "insight-1",
            summary = "A calm summary",
            tags = listOf("calm", "breath"),
            themes = listOf(NoteInsightTheme("calm", 1.0)),
        ),
    )

    var analysis: NoteInsightsAnalysis = NoteInsightsAnalysis(
        insights = insights,
        source = "heuristic",
    )

    /** How often the stored pass was asked for — the tests count the reloads. */
    var storedCalls: Int = 0

    override fun heuristic(): List<NoteInsight> = insights

    override fun stored(): List<NoteInsight> {
        storedCalls++
        return insights
    }

    override fun analyze(): NoteInsightsAnalysis = analysis
}
