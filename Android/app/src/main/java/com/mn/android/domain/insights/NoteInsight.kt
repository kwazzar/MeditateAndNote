package com.mn.android.domain.insights

/**
 * One note's insight.
 *
 * The analysis itself lives in Core (`HeuristicNoteAnalyzer`, the provider
 * protocol); this is the decoded result the app renders.
 */
data class NoteInsight(
    val id: String,
    val summary: String,
    val tags: List<String>,
    val themes: List<NoteInsightTheme>,
)

/** A theme the note matched, with how strongly it matched. */
data class NoteInsightTheme(
    val label: String,
    val relevance: Double,
)

/**
 * The result of an analysis pass: the insights, where they came from
 * ("llm" or "heuristic") and the error, when there was one.
 *
 * A failure is data, not an exception: the screen shows the old insights and
 * the error, so the pass has to be able to fail without throwing.
 */
data class NoteInsightsAnalysis(
    val insights: List<NoteInsight>,
    val source: String,
    val error: String? = null,
)
