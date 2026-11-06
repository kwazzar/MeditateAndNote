package com.mn.android.data

import com.mn.android.domain.insights.NoteInsight
import com.mn.android.domain.insights.NoteInsightTheme
import com.mn.android.domain.insights.NoteInsightsAnalysis
import org.json.JSONArray
import org.json.JSONObject

/**
 * Kotlin side of the note-insights read.
 *
 * Swift runs the domain analyzer (Core's `HeuristicNoteAnalyzer`) over the
 * stored notes and returns one JSON document; this file only decodes it into
 * the value objects the Compose screen renders. The theme/summary/tag rules
 * live in Core — there is no Kotlin reimplementation of the analysis to drift.
 *
 * Swift side: `Java_com_mn_android_data_NoteInsightsSource_read` in
 * AiInsightsBridge.swift.
 */
object NoteInsightsSource {

    init {
        // Same forced .so load as NoteMenuSource: the notes tab can be the
        // first JNI touch of the process.
        Class.forName("com.mn.core.AIDraftMetric")
    }

    /** The heuristic pass — always available, costs nothing. */
    external fun read(): String

    /** The persisted insights — no analysis, no provider call. */
    external fun stored(): String

    /** An analysis pass: provider first, heuristic as the fallback. */
    external fun analyze(): String

    /**
     * Insights in note order — the blob store hands the notes over newest
     * first, so index 0 is the freshest note.
     */
    fun load(): List<NoteInsight> {
        val root = JSONObject(read())
        return root.getJSONArray("insights").mapObjects { insight(it) }
    }

    /** The insights of the last analysis pass, as they were stored. */
    fun storedInsights(): List<NoteInsight> {
        val root = try {
            JSONObject(stored())
        } catch (error: Exception) {
            return emptyList()
        }
        return insights(root)
    }

    /** Runs an analysis pass. Never throws: a failure comes back as data. */
    fun analyzeInsights(): NoteInsightsAnalysis {
        val root = try {
            JSONObject(analyze())
        } catch (error: Exception) {
            return NoteInsightsAnalysis(emptyList(), source = "", error = "providerUnavailable")
        }
        if (!root.optBoolean("ok")) {
            return NoteInsightsAnalysis(emptyList(), source = "", error = root.optString("error"))
        }
        return NoteInsightsAnalysis(
            insights = insights(root),
            source = root.optString("source"),
        )
    }

    // MARK: - Decoding

    private fun insights(root: JSONObject): List<NoteInsight> =
        root.optJSONArray("insights")?.mapObjects { insight(it) } ?: emptyList()

    private fun insight(json: JSONObject) = NoteInsight(
        id = json.getString("id"),
        summary = json.getString("summary"),
        tags = json.getJSONArray("tags").mapStrings(),
        themes = json.getJSONArray("themes").mapObjects { theme(it) },
    )

    private fun theme(json: JSONObject) = NoteInsightTheme(
        label = json.getString("label"),
        relevance = json.getDouble("relevance"),
    )

    private inline fun <T> JSONArray.mapObjects(transform: (JSONObject) -> T): List<T> =
        (0 until length()).map { transform(getJSONObject(it)) }

    private fun JSONArray.mapStrings(): List<String> =
        (0 until length()).map { getString(it) }
}
