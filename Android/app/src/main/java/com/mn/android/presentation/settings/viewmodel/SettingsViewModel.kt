package com.mn.android.presentation.settings.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mn.android.domain.settings.AnimationStyle
import com.mn.android.domain.settings.AnimationStyleStore
import com.mn.android.domain.settings.ReminderSettings
import com.mn.android.domain.settings.ReminderSettingsStore
import com.mn.android.domain.settings.ReminderScheduler
import com.mn.android.domain.settings.SoundVolumeStore
import com.mn.android.domain.theme.ThemeSelectionStore
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * The settings screen's state: reminder, animation, sound, theme.
 */
class SettingsViewModel(
    private val reminderStore: ReminderSettingsStore,
    private val reminderScheduler: ReminderScheduler,
    private val soundVolume: SoundVolumeStore,
    private val animationStyleStore: AnimationStyleStore,
    private val themeStore: ThemeSelectionStore,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : ViewModel() {

    // The reminder form: backed by the store, synced on every change.
    private val initial = reminderStore.load()
    private val _enabled = MutableStateFlow(initial.enabled)
    private val _hour = MutableStateFlow(initial.hour)
    private val _minute = MutableStateFlow(initial.minute)
    private val _weekdays = MutableStateFlow<Set<Int>>(initial.weekdays)

    val enabled: StateFlow<Boolean> = _enabled
    val hour: StateFlow<Int> = _hour
    val minute: StateFlow<Int> = _minute
    val weekdays: StateFlow<Set<Int>> = _weekdays

    /** Updates the enabled state and persists it. */
    fun setEnabled(value: Boolean) {
        _enabled.value = value
        persistReminder()
    }

    /** Updates the time and persists it. */
    fun setTime(hour: Int, minute: Int) {
        _hour.value = hour
        _minute.value = minute
        persistReminder()
    }

    /** Toggles a weekday and persists it. */
    fun toggleWeekday(day: Int) {
        val current = _weekdays.value
        _weekdays.value = if (day in current) current - day else current + day
        persistReminder()
    }

    /** Persists the reminder settings and reschedules the alarm. */
    private fun persistReminder() {
        viewModelScope.launch {
            val settings = ReminderSettings(
                enabled = _enabled.value,
                hour = _hour.value,
                minute = _minute.value,
                weekdays = _weekdays.value,
            )
            reminderStore.save(settings)
            reminderScheduler.reschedule()
        }
    }

    // The sound volume: backed by the store.
    private val _volume = MutableStateFlow(soundVolume.volume)
    val volume: StateFlow<Float> = _volume

    fun setVolume(value: Float) {
        _volume.value = value
        soundVolume.volume = value
    }

    // The animation style: backed by the store.
    private val _animationStyle = MutableStateFlow(animationStyleStore.style)
    val animationStyle: StateFlow<AnimationStyle> = _animationStyle

    fun setAnimationStyle(style: AnimationStyle) {
        _animationStyle.value = style
        animationStyleStore.style = style
    }

    // The theme selection: backed by the store.
    private val _themeSelection = MutableStateFlow(themeStore.selected)
    val themeSelection: StateFlow<com.mn.android.domain.theme.model.MainTheme> = _themeSelection

    fun setThemeSelection(theme: com.mn.android.domain.theme.model.MainTheme) {
        _themeSelection.value = theme
        themeStore.selected = theme
    }
}
