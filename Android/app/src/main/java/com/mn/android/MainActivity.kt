package com.mn.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.toArgb
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.mn.android.data.OnboardingStore
import com.mn.android.ui.home.HomeScreen
import com.mn.android.ui.meditate.MeditateSelectScreen
import com.mn.android.ui.onboarding.OnboardingScreen
import com.mn.android.ui.theme.MnTheme

/**
 * Application shell: the navigation graph, and the start destination switch
 * driven by the completed-onboarding flag.
 *
 * This is the launcher now. `MetricsActivity` stays in the manifest without a
 * LAUNCHER filter so the device probes keep starting over `adb shell am start`
 * while the app itself opens on the real flow.
 *
 * Screens live in the graph rather than in an `if` chain because Navigation
 * Compose is where this project is going anyway — see the Router item in
 * ANDROID_PORT_PLAN Phase 4. Two destinations do not need it, but rewriting the
 * shell once more when the third screen lands would cost more than the graph
 * does.
 */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // darkZen background behind the system bars, so their icons stay
        // legible instead of inheriting the activity theme's light-mode values.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(MnTheme.background.toArgb()),
            navigationBarStyle = SystemBarStyle.dark(MnTheme.background.toArgb()),
        )

        setContent {
            MaterialTheme {
                MnNav()
            }
        }
    }
}

@Composable
private fun MnNav() {
    // Configured before the first read: the flag picks the start destination,
    // so it has to be resolvable the moment the graph is built.
    OnboardingStore.configure(LocalContext.current)

    val navController = rememberNavController()
    val startDestination =
        if (OnboardingStore.hasCompletedOnboarding) "home" else "onboarding"

    NavHost(navController = navController, startDestination = startDestination) {
        composable("onboarding") {
            OnboardingScreen(
                onCompleted = {
                    OnboardingStore.hasCompletedOnboarding = true
                    navController.navigate("home") {
                        popUpTo("onboarding") { inclusive = true }
                    }
                }
            )
        }
        composable("home") {
            HomeScreen(onMeditate = { navController.navigate("meditate") })
        }
        composable("meditate") {
            MeditateSelectScreen(onBack = { navController.popBackStack() })
        }
    }
}
