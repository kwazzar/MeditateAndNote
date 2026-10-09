package com.mn.android.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SharedPrefsReminderSettingsStoreContractTest {

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        SharedPrefsReminderSettingsStore.configure(context)
    }

    @Test
    fun load_returnsDefaultValuesWhenNotSet() {
        val loaded = SharedPrefsReminderSettingsStore.load()
        assertEquals(0L, loaded[0])
        assertEquals(20L, loaded[1])
        assertEquals(0L, loaded[2])
        assertEquals(7, loaded.size)
    }

    @Test
    fun saveStoresEnabledState() {
        SharedPrefsReminderSettingsStore.save(enabled = true, hour = 10, minute = 30, weekdays = longArrayOf(1, 2, 3, 4, 5, 6, 7))

        val loaded = SharedPrefsReminderSettingsStore.load()
        assertEquals(1L, loaded[0])
        assertEquals(10, loaded[1].toInt())
        assertEquals(30, loaded[2].toInt())
    }
}