package com.mn.android.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SessionRecorderContractTest {

    @Test
    fun record_returnsNonNegativeLong() {
        val result = SessionRecorder.record("test-meditation-id", 120.0)
        assertTrue("Result should be non-negative, was: $result", result >= 0)
    }
}