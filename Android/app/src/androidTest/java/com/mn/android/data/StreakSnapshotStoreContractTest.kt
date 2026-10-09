package com.mn.android.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class StreakSnapshotStoreContractTest {

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        StreakSnapshotStore.configure(context)
    }

    @Test
    fun load_returnsEmptyStringByDefault() {
        assertEquals("", StreakSnapshotStore.load())
    }

    @Test
    fun saveAndLoad_persistsJson() {
        val json = """{"streak": 5, "lastCompleted": 1700000000}"""
        StreakSnapshotStore.save(json)
        assertEquals(json, StreakSnapshotStore.load())
    }

    @Test
    fun saveReplacesExistingData() {
        StreakSnapshotStore.save("""{"old": true}""")
        StreakSnapshotStore.save("""{"new": true}""")
        assertEquals("""{"new": true}""", StreakSnapshotStore.load())
    }
}