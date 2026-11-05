package com.mn.android.infrastructure.analytics

import org.junit.Assert.assertEquals
import org.junit.Test

class AnalyticsUserPropertiesTest {

    @Test
    fun `streak bucket covers every range`() {
        assertEquals("0", AnalyticsUserProperties.streakBucket(0))
        assertEquals("0", AnalyticsUserProperties.streakBucket(-1))
        assertEquals("1-3", AnalyticsUserProperties.streakBucket(1))
        assertEquals("1-3", AnalyticsUserProperties.streakBucket(3))
        assertEquals("4-7", AnalyticsUserProperties.streakBucket(4))
        assertEquals("4-7", AnalyticsUserProperties.streakBucket(7))
        assertEquals("8-14", AnalyticsUserProperties.streakBucket(8))
        assertEquals("8-14", AnalyticsUserProperties.streakBucket(14))
        assertEquals("15+", AnalyticsUserProperties.streakBucket(15))
        assertEquals("15+", AnalyticsUserProperties.streakBucket(400))
    }

    @Test
    fun `premium and onboarding values are fixed strings`() {
        assertEquals("pro", AnalyticsUserProperties.premiumStatus(true))
        assertEquals("free", AnalyticsUserProperties.premiumStatus(false))
        assertEquals("true", AnalyticsUserProperties.onboardingCompleted(true))
        assertEquals("false", AnalyticsUserProperties.onboardingCompleted(false))
    }
}
