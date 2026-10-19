package com.mn.android.data

import org.json.JSONArray
import org.json.JSONObject

/**
 * Kotlin side of the AI draft commands.
 *
 * Swift owns the domain: the session state machine, the free-quota rule and
 * the parsing of the model's answer live in the core package. Kotlin calls
 * the commands and renders the session it gets back - the session document
 * itself stays opaque here, it is handed back unchanged for the next
 * transition.
 */
object AIDraftSource {

    init {
        // Force the .so load: the editor can be the first JNI touch of the
        // process (same trick as NoteEditorSource).
        Class.forName("com.mn.core.AIDraftMetric")
    }

    external fun startDraft(instruction: String, context: String, noteId: String): String
    external fun acceptSuggestion(session: String, suggestionId: String): String
    external fun acceptAll(session: String): String
    external fun rejectSuggestion(session: String, suggestionId: String): String
    external fun cancel(session: String): String

    data class Suggestion(
        val id: String,
        val text: String,
        val rationale: String,
    )

    data class Session(
        val id: String,
        val noteId: String,
        /** "idle" | "generating" | "ready" | "cancelled" | "failed" */
        val state: String,
        /** The AIDraftError raw value when the state is "failed". */
        val error: String?,
        val suggestions: List<Suggestion>,
        val accepted: List<Suggestion>,
        /** True when the prompt carried note text - then the model continues. */
        val grounded: Boolean,
    ) {
        val isReady: Boolean get() = state == "ready"
        val pending: List<Suggestion>
            get() = suggestions.filter { suggestion -> accepted.none { it.id == suggestion.id } }
    }

    data class Result(
        val ok: Boolean,
        /** The session document, handed back unchanged for the next command. */
        val document: String?,
        val session: Session?,
        val error: String?,
    )

    fun start(noteId: String, instruction: String, context: String): Result =
        parse(startDraft(instruction, context, noteId))

    fun accept(session: String, suggestionId: String): Result =
        parse(acceptSuggestion(session, suggestionId))

    fun acceptAllPending(session: String): Result = parse(acceptAll(session))

    fun reject(session: String, suggestionId: String): Result =
        parse(rejectSuggestion(session, suggestionId))

    fun cancelDraft(session: String): Result = parse(cancel(session))

    // MARK: - Decoding

    private fun parse(json: String): Result {
        return try {
            val root = JSONObject(json)
            val sessionObject = root.optJSONObject("session")
            if (root.optBoolean("ok")) {
                Result(
                    ok = true,
                    document = sessionObject?.toString(),
                    session = sessionObject?.let { session(it) },
                    error = null,
                )
            } else {
                Result(ok = false, document = null, session = null, error = root.optString("error"))
            }
        } catch (error: Exception) {
            Result(ok = false, document = null, session = null, error = "providerUnavailable")
        }
    }

    private fun session(json: JSONObject): Session {
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

        return Session(
            id = json.optString("id"),
            noteId = json.optString("noteID").ifEmpty { prompt?.optString("noteID").orEmpty() },
            state = state,
            error = failure,
            suggestions = json.optJSONArray("suggestions").suggestions(),
            accepted = json.optJSONArray("acceptedSuggestions").suggestions(),
            grounded = !prompt?.optString("context").isNullOrBlank(),
        )
    }

    private fun JSONArray?.suggestions(): List<Suggestion> {
        if (this == null) return emptyList()
        return (0 until length()).map { index ->
            val obj = getJSONObject(index)
            Suggestion(
                id = obj.optString("id"),
                text = obj.optString("text"),
                rationale = obj.optString("rationale"),
            )
        }
    }
}
