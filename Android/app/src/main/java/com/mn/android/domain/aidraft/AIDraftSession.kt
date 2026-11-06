package com.mn.android.domain.aidraft

import com.mn.android.domain.note.NoteId

/**
 * The draft session on a note.
 *
 * The document is the bridge's own encoding of the session: Kotlin hands it
 * back unchanged for the next transition and never parses it.
 */
data class AIDraftSession(
    val id: String,
    val noteId: NoteId,
    val state: AIDraftState,
    val error: AIDraftError?,
    val suggestions: List<AIDraftSuggestion>,
    val accepted: List<AIDraftSuggestion>,
    /** True when the prompt carried note text - then the model continues. */
    val grounded: Boolean,
    /** The opaque session document, handed back for the next transition. */
    val document: String,
) {
    val isReady: Boolean get() = state == AIDraftState.READY

    /** The suggestions the user has not taken yet. */
    val pending: List<AIDraftSuggestion>
        get() = suggestions.filter { suggestion -> accepted.none { it.id == suggestion.id } }
}
