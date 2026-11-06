package com.mn.android.presentation.meditate.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mn.android.domain.meditation.MeditationRepository
import com.mn.android.domain.meditation.model.MeditationUi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MeditateSelectViewModel(
    private val meditationRepository: MeditationRepository
) : ViewModel() {

    private val _items = MutableStateFlow<List<MeditationUi>>(emptyList())
    val items: kotlinx.coroutines.flow.StateFlow<List<MeditationUi>> = _items.asStateFlow()

    private var _error: String? = null
    var error: String?
        get() = _error
        private set(value) {
            _error = value
        }

    fun loadCatalog() {
        viewModelScope.launch {
            try {
                val loaded = withContext(Dispatchers.IO) {
                    meditationRepository.catalog
                }
                _items.value = loaded
            } catch (e: Exception) {
                _error = "${e.javaClass.simpleName}: ${e.message}"
            }
        }
    }
}