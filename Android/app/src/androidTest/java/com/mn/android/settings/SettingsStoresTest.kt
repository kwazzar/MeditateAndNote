package com.mn.android.settings

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.mn.android.data.reminder.JniReminderSettingsStore
import com.mn.android.domain.settings.AnimationStyle
import com.mn.android.domain.settings.ReminderSettings
import com.mn.android.infrastructure.persistence.local.settings.AnimationSettings
import com.mn.android.infrastructure.persistence.local.settings.MnThemeStore
import com.mn.android.infrastructure.persistence.local.settings.SoundSettings
import com.mn.android.domain.theme.model.MainTheme
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The preference stores behind the new domain ports: the value the screens
 * read has to survive the round trip through the flat storage.
 */
@RunWith(AndroidJUnit4::class)
class SettingsStoresTest {

    private lateinit var context: Context

    @Before
    fun setup() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        listOf("reminder_settings", "soundSettings", "animationSettings", "theme").forEach { name ->
            context.getSharedPreferences(name, Context.MODE_PRIVATE).edit().clear().apply()
        }
    }

    @Test
    fun reminderSettings_nothingStored_isTheDefault() {
        val loaded = JniReminderSettingsStore(context).load()
        assertEquals(ReminderSettings.Default, loaded)
    }

    @Test
    fun reminderSettings_survivesTheRoundTrip() {
        val settings = ReminderSettings(
            enabled = true,
            hour = 7,
            minute = 45,
            weekdays = setOf(2, 5),
        )
        JniReminderSettingsStore(context).save(settings)
        assertEquals(settings, JniReminderSettingsStore(context).load())
    }

    @Test
    fun soundVolume_survivesTheRoundTrip() {
        SoundSettings.configure(context)
        SoundSettings.volume = 0.65f
        assertEquals(0.65f, SoundSettings.volume, 0.001f)
    }

    @Test
    fun animationStyle_survivesTheRoundTrip() {
        AnimationSettings.configure(context)
        AnimationSettings.style = AnimationStyle.RINGS
        assertEquals(AnimationStyle.RINGS, AnimationSettings.style)
    }

    @Test
    fun themeSelection_survivesTheRoundTrip() {
        MnThemeStore.configure(context)
        MnThemeStore.selected = MainTheme.DARK_ZEN
        assertEquals(MainTheme.DARK_ZEN, MnThemeStore.selected)
    }
}
