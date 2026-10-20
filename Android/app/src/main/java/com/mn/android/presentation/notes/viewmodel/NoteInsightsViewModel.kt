package com.mn.android.presentation.notes.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mn.android.data.NoteInsightsSource
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
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
 * three lambdas are the seam the tests replace.
 */
class NoteInsightsViewModel(
    private val loadStored: suspend () -> List<NoteInsightsSource.Insight> = { NoteInsightsSource.storedInsights() },
    private val loadHeuristic: suspend () -> List<NoteInsightsSource.Insight> = { NoteInsightsSource.load() },
    private val runAnalysis: suspend () -> NoteInsightsSource.Analysis = { NoteInsightsSource.analyzeInsights() },
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : ViewModel() {

    data class UiState(
        val insights: List<NoteInsightsSource.Insight> = emptyList(),
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
        get() = NoteInsightsSource.topThemes(state.value.insights)

    /**
     * The stored insights — what the last pass found. With nothing stored
     * yet, the heuristic ones: the analysis is a keyword count, so it is
     * cheap and always available.
     */
    fun load() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            val insights = withContext(ioDispatcher) {
                val stored = runCatching { loadStored() }.getOrDefault(emptyList())
                stored.ifEmpty { runCatching { loadHeuristic() }.getOrDefault(emptyList()) }
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
                runCatching { runAnalysis() }.getOrNull()
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
