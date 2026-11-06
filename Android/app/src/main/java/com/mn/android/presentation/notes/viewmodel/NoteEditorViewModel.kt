package com.mn.android.presentation.notes.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mn.android.application.analytics.StreakEvents
import com.mn.android.domain.aidraft.AIDraftError
import com.mn.android.domain.aidraft.AIDraftMetric
import com.mn.android.domain.aidraft.AIDraftMetricRecorder
import com.mn.android.domain.aidraft.AIDraftRepository
import com.mn.android.domain.aidraft.AIDraftSession
import com.mn.android.domain.aidraft.AIDraftSettings
import com.mn.android.domain.aidraft.AIDraftSuggestion
import com.mn.android.domain.events.DomainEvent
import com.mn.android.domain.events.DomainEventBus
import com.mn.android.domain.note.NoteDetail
import com.mn.android.domain.note.NoteDraft
import com.mn.android.domain.note.NoteId
import com.mn.android.domain.note.NoteRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * The note editor.
 *
 * The rules live here, not in the composable:
 * - a blank note that was never stored is a mis-tap, never an intent
 * - the autosave waits 800 ms after the last change, like the iOS ViewModel
 * - the back button saves, the delete asks first
 * - the AI draft bar shows what the session holds and nothing else
 *
 * The domain rules themselves stay in Swift: the title is normalised there and
 * comes back with the saved note, the draft's session state machine and the
 * free-quota rule live in the core package.
 */
class NoteEditorViewModel(
    private val noteId: NoteId,
    /** True until the note is stored for the first time. */
    private val isNew: Boolean,
    private val notes: NoteRepository,
    private val drafts: AIDraftRepository,
    private val draftSettings: AIDraftSettings,
    private val metricRecorder: AIDraftMetricRecorder,
    /**
     * The scope for the writes that must not be cancelled by the screen
     * going away: the save on the way back and the delete.
     */
    private val backgroundScope: CoroutineScope,
    private val autosaveDelayMs: Long = 800,
) : ViewModel() {

    data class UiState(
        val id: NoteId,
        val isNew: Boolean = true,
        val isLoading: Boolean = false,
        val title: String = "",
        val body: String = "",
        /** The note as it was last stored; null while it was never stored. */
        val persisted: NoteDetail? = null,
        val draft: DraftState = DraftState(),
    ) {
        /** The note changed since it was stored. */
        val isDirty: Boolean
            get() = persisted?.let { it.title != title || it.content != body }
                ?: (title.isNotEmpty() || body.isNotEmpty())

        /** An all-blank note is a mis-tap, never an intent. */
        val hasContent: Boolean
            get() = title.isNotBlank() || body.isNotBlank()

        /** The delete is offered once the note is stored. */
        val canDelete: Boolean
            get() = !isNew
    }

    data class DraftState(
        val isGenerating: Boolean = false,
        val session: AIDraftSession? = null,
        val error: AIDraftError? = null,
    )

    private val _state = MutableStateFlow(UiState(id = noteId, isNew = isNew))
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var autosave: Job? = null

    /** Cold or warm start, the way the iOS manager reports it. */
    private var hasGenerated = false

    init {
        if (!isNew) load()
    }

    // MARK: - Load

    private fun load() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            val detail = notes.get(noteId).getOrNull()
            _state.update {
                it.copy(
                    isLoading = false,
                    title = detail?.title.orEmpty(),
                    body = detail?.content.orEmpty(),
                    persisted = detail,
                )
            }
            // The draft the user left behind comes back with the note - a
            // new draft would burn another generation of the free allowance.
            val stored = drafts.stored(noteId)
            if (stored.session != null) {
                _state.update { it.copy(draft = it.draft.copy(session = stored.session)) }
            }
        }
    }

    // MARK: - Text

    fun onTitleChange(value: String) {
        _state.update { it.copy(title = value) }
        scheduleAutosave()
    }

    fun onBodyChange(value: String) {
        _state.update { it.copy(body = value) }
        scheduleAutosave()
    }

    /** Autosave: debounced, only while dirty — 800 ms like the iOS ViewModel. */
    private fun scheduleAutosave() {
        autosave?.cancel()
        autosave = viewModelScope.launch {
            delay(autosaveDelayMs)
            saveNow()
        }
    }

    // MARK: - Save

    /** The back button saves before it leaves. */
    fun save() {
        backgroundScope.launch { saveNow() }
    }

    private suspend fun saveNow() {
        val current = _state.value
        if (current.isLoading) return
        if (current.isNew && !current.hasContent) return
        if (!current.isDirty) return
        val wasNew = current.persisted == null
        val saved = notes.save(current.id, NoteDraft(current.title, current.body)).getOrNull() ?: return
        _state.update {
            it.copy(
                title = saved.title,
                persisted = saved,
                isNew = false,
            )
        }
        // A new note fills the streak day it was written on; only the new-note
        // path can move the streak, same as iOS.
        if (wasNew) StreakEvents.sync()
    }

    // MARK: - Delete

    fun delete() {
        backgroundScope.launch {
            notes.delete(noteId)
            // The note is gone, so is its draft - the same rule iOS applies.
            drafts.discard(noteId)
        }
    }

    // MARK: - AI draft

    fun startDraft() {
        val current = _state.value
        if (current.draft.isGenerating) return
        if (!draftSettings.isConfigured()) {
            _state.update { it.copy(draft = it.draft.copy(error = AIDraftError.NoProvider())) }
            return
        }
        viewModelScope.launch {
            _state.update { it.copy(draft = it.draft.copy(isGenerating = true, error = null)) }
            val warm = !hasGenerated
            hasGenerated = true
            recordMetric(AIDraftMetric(kind = "generationStarted", warmCold = warm))
            val result = drafts.start(noteId, instruction = "", context = current.body)
            applyResult(result)
            // iOS `publishGenerated`: once per successful generation, never on
            // accept/reject transitions (their results carry a session too).
            if (result.ok && result.session != null) {
                DomainEventBus.publish(DomainEvent.AiDraftGenerated)
            }
        }
    }

    fun acceptSuggestion(suggestion: AIDraftSuggestion) {
        val session = _state.value.draft.session ?: return
        viewModelScope.launch { applyResult(drafts.accept(session, suggestion.id)) }
    }

    fun removeSuggestion(suggestion: AIDraftSuggestion) {
        val session = _state.value.draft.session ?: return
        recordSuggestionEvent("suggestionRejected", suggestion)
        viewModelScope.launch { applyResult(drafts.reject(session, suggestion.id)) }
    }

    fun acceptAllSuggestions() {
        val session = _state.value.draft.session ?: return
        viewModelScope.launch { applyResult(drafts.acceptAll(session)) }
    }

    /** iOS `applyAcceptedProposals`: the accepted texts, blank line separated. */
    fun transferAccepted() {
        val accepted = _state.value.draft.session?.accepted.orEmpty()
        if (accepted.isEmpty()) return
        accepted.forEach { recordSuggestionEvent("suggestionInserted", it) }
        val addition = accepted.joinToString("\n\n") { it.text.trim('\n', '\r') }
        val body = _state.value.body
        onBodyChange(if (body.isBlank()) addition else "$body\n\n$addition")
    }

    private fun applyResult(result: com.mn.android.domain.aidraft.AIDraftResult) {
        result.metric?.let { recordMetric(it) }
        if (result.ok && result.session != null) {
            _state.update {
                it.copy(draft = it.draft.copy(isGenerating = false, session = result.session, error = null))
            }
        } else {
            _state.update {
                it.copy(draft = it.draft.copy(isGenerating = false, error = result.error))
            }
        }
    }

    /** The telemetry event for a suggestion the user took or dropped. */
    private fun recordSuggestionEvent(kind: String, suggestion: AIDraftSuggestion) {
        val index = _state.value.draft.session?.suggestions?.indexOfFirst { it.id == suggestion.id } ?: -1
        if (index < 0) return
        recordMetric(AIDraftMetric(kind = kind, suggestionIndex = index.toLong()))
    }

    private fun recordMetric(metric: AIDraftMetric) {
        viewModelScope.launch { metricRecorder.record(metric) }
        metric.toDomainEvent()?.let(DomainEventBus::publish)
    }
}

/**
 * The bridge's flat metric -> typed [DomainEvent.AiDraftMetric]. The kinds are
 * fixed by `AIDraftBridge.swift`; unknown kinds (future bridge versions) are
 * dropped rather than guessed at.
 */
private fun AIDraftMetric.toDomainEvent(): DomainEvent.AiDraftMetric? = when (kind) {
    "generationStarted" -> warmCold?.let(DomainEvent.AiDraftMetric::GenerationStarted)
    "generationCompleted" ->
        latencyMs?.let { ms ->
            suggestionCount?.let { count ->
                DomainEvent.AiDraftMetric.GenerationCompleted(ms.toInt(), count.toInt())
            }
        }
    "generationFailed" -> errorKind?.let(DomainEvent.AiDraftMetric::GenerationFailed)
    "suggestionInserted" -> suggestionIndex?.let { DomainEvent.AiDraftMetric.SuggestionInserted(it.toInt()) }
    "suggestionRejected" -> suggestionIndex?.let { DomainEvent.AiDraftMetric.SuggestionRejected(it.toInt()) }
    else -> null
}
