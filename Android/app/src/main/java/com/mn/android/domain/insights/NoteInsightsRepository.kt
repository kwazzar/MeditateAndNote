package com.mn.android.domain.insights

/**
 * The note-insights reads.
 *
 * Swift runs the analyzer (Core's `HeuristicNoteAnalyzer`, the provider
 * protocol) over the stored notes; Kotlin only decodes what comes back. The
 * calls block — they cross into Swift — so the caller moves them off the main
 * thread.
 */
interface NoteInsightsRepository {

    /** The heuristic pass — always available, costs nothing. */
    fun heuristic(): List<NoteInsight>

    /** The persisted insights — no analysis, no provider call. */
    fun stored(): List<NoteInsight>

    /** An analysis pass: provider first, heuristic as the fallback. */
    fun analyze(): NoteInsightsAnalysis
}
