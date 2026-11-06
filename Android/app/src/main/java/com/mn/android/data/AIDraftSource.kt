package com.mn.android.data

import com.mn.android.domain.aidraft.AIDraftError
import com.mn.android.domain.aidraft.AIDraftMetric
import com.mn.android.domain.aidraft.AIDraftResult
import com.mn.android.domain.aidraft.AIDraftSession
import com.mn.android.domain.aidraft.AIDraftState
import com.mn.android.domain.aidraft.AIDraftSuggestion
import com.mn.android.domain.note.NoteId
import org.json.JSONArray
import org.json.JSONObject

/**
 * Kotlin side of the AI draft commands.
 *
 * Swift owns the domain: the session state machine, the free-quota rule and
 * the parsing of the model's answer live in the core package. Kotlin calls
 * the commands and decodes what comes back - the session document itself stays
 * opaque here, it is handed back unchanged for the next transition.
 *
 * The decoding produces the domain value objects: the wire format never
 * reaches the screens.
 */
object AIDraftSource {

    init {
        // Force the .so load: the editor can be the first JNI touch of the
        // process (same trick as NoteEditorSource).
        Class.forName("com.mn.core.AIDraftMetric")
    }

    external fun startDraft(instruction: String, context: String, noteId: String): String
    external fun session(noteId: String): String
    external fun discardSession(noteId: String)
    external fun acceptSuggestion(session: String, suggestionId: String): String
    external fun acceptAll(session: String): String
    external fun rejectSuggestion(session: String, suggestionId: String): String
    external fun cancel(session: String): String

    fun start(noteId: String, instruction: String, context: String): AIDraftResult =
        parse(startDraft(instruction, context, noteId))

    /** The session left behind on this note, if any. */
    fun stored(noteId: String): AIDraftResult = parse(session(noteId))

    /** Drops the stored session - the note is gone, so is its draft. */
    fun discard(noteId: String) {
        discardSession(noteId)
    }

    fun accept(session: String, suggestionId: String): AIDraftResult =
        parse(acceptSuggestion(session, suggestionId))

    fun acceptAllPending(session: String): AIDraftResult = parse(acceptAll(session))

    fun reject(session: String, suggestionId: String): AIDraftResult =
        parse(rejectSuggestion(session, suggestionId))

    fun cancelDraft(session: String): AIDraftResult = parse(cancel(session))

    // MARK: - Decoding

    private fun parse(json: String): AIDraftResult {
        return try {
            val root = JSONObject(json)
            val sessionObject = root.optJSONObject("session")
            val metric = root.optJSONObject("metric")?.let { metric(it) }
            if (root.optBoolean("ok")) {
                AIDraftResult(
                    session = sessionObject?.let { session(it) },
                    metric = metric,
                    error = null,
                )
            } else {
                AIDraftResult(
                    session = null,
                    metric = metric,
                    error = error(root.optString("error")),
                )
            }
        } catch (error: Exception) {
            AIDraftResult(session = null, metric = null, error = error("providerUnavailable"))
        }
    }

    /** The bridge names its failures; the domain names what the user sees. */
    private fun error(raw: String): AIDraftError = when (raw) {
        "freeQuotaExhausted" -> AIDraftError.FreeQuotaExhausted()
        else -> AIDraftError.Failed(raw)
    }

    private fun metric(json: JSONObject) = AIDraftMetric(
        kind = json.optString("kind"),
        latencyMs = json.optLongOrNull("latencyMs"),
        suggestionCount = json.optLongOrNull("suggestionCount"),
        errorKind = json.optString("errorKind").takeIf { it.isNotEmpty() },
        suggestionIndex = json.optLongOrNull("suggestionIndex"),
    )

    private fun JSONObject.optLongOrNull(key: String): Long? =
        if (isNull(key) || !has(key)) null else getLong(key)

    private fun session(json: JSONObject): AIDraftSession {
        val prompt = json.optJSONObject("prompt")
        var state = "idle"
        var failure: String? = null
        when (val value = json.opt("state")) {
            is String -> state = value
            is JSONObject -> {
                // Swift encodes the state as its case name: {"ready": {}},
                // {"failed": {"_0": "…"}}. A case without a payload carries an
                // empty object, a failed one the error inside it.
                val case = value.keys().asSequence().firstOrNull() ?: "idle"
                state = case
                failure = value.optJSONObject(case)?.optString("_0")?.takeIf { it.isNotEmpty() }
            }
        }

        return AIDraftSession(
            id = json.optString("id"),
            noteId = NoteId(json.optString("noteID").ifEmpty { prompt?.optString("noteID").orEmpty() }),
            state = AIDraftState.of(state),
            error = failure?.let { error(it) },
            suggestions = json.optJSONArray("suggestions").suggestions(),
            accepted = json.optJSONArray("acceptedSuggestions").suggestions(),
            grounded = !prompt?.optString("context").isNullOrBlank(),
            document = json.toString(),
        )
    }

    private fun JSONArray?.suggestions(): List<AIDraftSuggestion> {
        if (this == null) return emptyList()
        return (0 until length()).map { index ->
            val obj = getJSONObject(index)
            AIDraftSuggestion(
                id = obj.optString("id"),
                text = obj.optString("text"),
                rationale = obj.optString("rationale"),
            )
        }
    }
}
