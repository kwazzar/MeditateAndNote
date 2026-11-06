package com.mn.android.presentation.notes.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mn.android.domain.insights.NoteInsight
import com.mn.android.domain.insights.NoteInsightsRepository
import com.mn.android.domain.events.DomainEvent
import com.mn.android.domain.events.DomainEventBus
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * The Android counterpart of iOS `NoteInsightsViewModel`.
 *
 * It holds the state the notes tab draws — the insights, whether a pass is
 * running, the last error — and it survives the tab switches, so the section
 * does not re-analyze every time the user comes back.
 *
 * The analysis rules are not here: Swift owns them (`HeuristicNoteAnalyzer`,
 * `NoteInsightRemoteProtocol`) and Kotlin only decodes what comes back. The
 * repository is the seam the tests replace.
 */
class NoteInsightsViewModel(
    private val repository: NoteInsightsRepository,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val events: Flow<DomainEvent> = DomainEventBus.events,
) : ViewModel() {

    init {
        // The iOS ViewModel listens for the same events: a note change makes
        // the stored insights stale, so they are read again.
        viewModelScope.launch {
            events.collect { event ->
                if (event is DomainEvent.NoteCreated ||
                    event is DomainEvent.NoteUpdated ||
                    event is DomainEvent.NoteDeleted
                ) {
                    load()
                }
            }
        }
    }

    data class UiState(
        val insights: List<NoteInsight> = emptyList(),
        val isLoading: Boolean = false,
        val isRefreshing: Boolean = false,
        /** The error of the last pass, "providerUnavailable" by default. */
        val error: String? = null,
        val hasLoaded: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())

    val state: StateFlow<UiState> = _state.asStateFlow()

    /** Aggregate theme labels across all insights, most frequent first. */
    val topThemes: List<String>
        get() {
            val counts = LinkedHashMap<String, Int>()
            for (insight in state.value.insights) {
                for (theme in insight.themes) {
                    counts[theme.label] = (counts[theme.label] ?: 0) + 1
                }
            }
            return counts.entries.sortedByDescending { it.value }.take(5).map { it.key }
        }

    /**
     * The stored insights — what the last pass found. With nothing stored
     * yet, the heuristic ones: the analysis is a keyword count, so it is
     * cheap and always available.
     */
    fun load() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            val insights = withContext(ioDispatcher) {
                val stored = runCatching { repository.stored() }.getOrDefault(emptyList())
                stored.ifEmpty { runCatching { repository.heuristic() }.getOrDefault(emptyList()) }
            }
            _state.update { it.copy(insights = insights, isLoading = false, hasLoaded = true) }
        }
    }

    /**
     * Force an analysis pass: the provider is asked once, the answer is
     * persisted by Swift, and the section shows what came back. A failure
     * keeps the old insights on screen and reports the error.
     */
    fun refresh() {
        if (_state.value.isRefreshing) return
        viewModelScope.launch {
            _state.update { it.copy(isRefreshing = true, error = null) }
            val analysis = withContext(ioDispatcher) {
                runCatching { repository.analyze() }.getOrNull()
            }
            if (analysis == null || analysis.error != null) {
                _state.update {
                    it.copy(isRefreshing = false, error = analysis?.error ?: "providerUnavailable")
                }
            } else {
                _state.update {
                    it.copy(
                        insights = analysis.insights,
                        isRefreshing = false,
                        hasLoaded = true,
                        error = null,
                    )
                }
            }
        }
    }
}
