package com.mn.android.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class OnboardingStoreContractTest {

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        OnboardingStore.configure(context)
    }

    @Test
    fun hasCompletedOnboarding_returnsFalseByDefault() {
        assertFalse(OnboardingStore.hasCompletedOnboarding)
    }

    @Test
    fun hasCompletedOnboarding_canBeSet() {
        OnboardingStore.hasCompletedOnboarding = true
        assertTrue(OnboardingStore.hasCompletedOnboarding)
        OnboardingStore.hasCompletedOnboarding = false
        assertFalse(OnboardingStore.hasCompletedOnboarding)
    }
}