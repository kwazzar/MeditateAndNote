package com.mn.android.presentation.meditate

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.mn.android.presentation.meditate.viewmodel.BreathingSessionViewModel
import com.mn.core.SessionDuration
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.swift.swiftkit.core.SwiftMemoryManagement

/**
 * A nav pop (system back/gesture) clears the ViewModelStore without going
 * through the close button. The ticker's runnable holds the ViewModel, so if
 * `onCleared` did not stop it the abandoned session keeps ticking — and later
 * records a completed session.
 */
@RunWith(AndroidJUnit4::class)
class BreathingSessionViewModelTest {

    @Test
    fun clearingTheViewModel_stopsTheSessionAndItsTicker() {
        val vm = BreathingSessionViewModel(SavedStateHandle(mapOf("meditationId" to "3")))
        val store = ViewModelStore()
        ViewModelProvider(store, vmFactory(vm))[BreathingSessionViewModel::class.java]

        vm.start(SessionDuration.init(60.0, SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA))
        assertNotNull("ticker runs while the session is live", tickerOf(vm))

        InstrumentationRegistry.getInstrumentation().runOnMainSync { store.clear() }

        assertTrue(
            "pop must return the engine to Idle",
            vm.uiState is BreathingSessionViewModel.UiState.Idle,
        )
        assertNull("pop must cancel the ticker", tickerOf(vm))
    }

    private fun vmFactory(vm: BreathingSessionViewModel) = object : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T = vm as T
    }

    private fun tickerOf(vm: BreathingSessionViewModel): Any? =
        BreathingSessionViewModel::class.java
            .getDeclaredField("ticker")
            .apply { isAccessible = true }
            .get(vm)
}
