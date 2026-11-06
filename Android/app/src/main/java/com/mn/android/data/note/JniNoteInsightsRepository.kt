package com.mn.android.data.note

import com.mn.android.data.NoteInsightsSource
import com.mn.android.domain.insights.NoteInsight
import com.mn.android.domain.insights.NoteInsightsAnalysis
import com.mn.android.domain.insights.NoteInsightsRepository

/**
 * The note-insights reads, over the JNI bridge.
 *
 * The bridge decodes the JSON document Swift returns; this adapter is the
 * port the app depends on. The calls block (they cross into Swift), so the
 * caller moves them off the main thread — the same rule the streak
 * repository follows.
 */
class JniNoteInsightsRepository(
    private val source: NoteInsightsSource = NoteInsightsSource,
) : NoteInsightsRepository {

    override fun heuristic(): List<NoteInsight> = source.load()

    override fun stored(): List<NoteInsight> = source.storedInsights()

    override fun analyze(): NoteInsightsAnalysis = source.analyzeInsights()
}
