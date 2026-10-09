package com.mn.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Notes
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.mn.android.R
import com.mn.android.data.NoteBlobStore
import com.mn.android.data.OnboardingStore
import com.mn.android.data.SharedPrefsReminderSettingsStore
import com.mn.android.data.StreakSnapshotStore
import com.mn.android.ui.home.HomeScreen
import com.mn.android.ui.settings.SettingsScreen
import com.mn.android.ui.meditate.BreathingScreen
import com.mn.android.ui.meditate.MeditateSelectScreen
import com.mn.android.ui.notes.NoteEditorScreen
import com.mn.android.ui.notes.NoteMenuScreen
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
    // so it has to be resolvable the moment the graph is built. The streak
    // and note stores need the same injection — home and the notes tab read
    // them on first composition, and an unconfigured store reads as
    // "no data yet".
    OnboardingStore.configure(LocalContext.current)
    StreakSnapshotStore.configure(LocalContext.current)
    NoteBlobStore.configure(LocalContext.current)
    SharedPrefsReminderSettingsStore.configure(LocalContext.current)

    val navController = rememberNavController()
    val startDestination =
        if (OnboardingStore.hasCompletedOnboarding) "home" else "onboarding"

    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route

    Scaffold(
        containerColor = MnTheme.background,
        bottomBar = {
            if (currentRoute in TabBarRoutes) {
                NavigationBar(
                    containerColor = MnTheme.background,
                    tonalElevation = 0.dp,
                ) {
                    TabBarItems.forEach { tab ->
                        val selected = currentRoute == tab.route
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(tab.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(tab.icon, contentDescription = null)
                            },
                            label = { Text(tab.labelResourceId.let { stringResource(it) }) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = MnTheme.textPrimary,
                                selectedTextColor = MnTheme.textPrimary,
                                unselectedIconColor = MnTheme.textSecondary,
                                unselectedTextColor = MnTheme.textSecondary,
                                indicatorColor = MnTheme.cardBackground,
                            ),
                        )
                    }
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = startDestination,
            modifier = Modifier.padding(innerPadding),
        ) {
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
                HomeScreen(
                    onMeditate = { navController.navigate("meditate") },
                    onStreakDetail = { navController.navigate("streakDetail") },
                    onSettings = { navController.navigate("settings") },
                    onNewNote = { navController.navigate("newNote") },
                )
            }
            composable("notes") {
                NoteMenuScreen(
                    onOpenNote = { id -> navController.navigate("noteDetails/$id") },
                    onAddNote = { navController.navigate("newNote") },
                )
            }
            // Stub destinations: screens exist on iOS but are not ported yet. The
            // routes keep the tab entries wired end to end; the placeholder body
            // is replaced when each screen lands.
            composable("streakDetail") {
                PlaceholderScreen("Streak Detail")
            }
            composable("settings") {
                SettingsScreen(
                    onBack = { navController.popBackStack() },
                    onShowOnboarding = {
                        OnboardingStore.hasCompletedOnboarding = false
                        navController.navigate("onboarding")
                    },
                )
            }
            composable("newNote") {
                NoteEditorScreen(
                    noteId = null,
                    onBack = { navController.popBackStack() },
                )
            }
            composable("noteDetails/{noteId}") { backStackEntry ->
                val id = backStackEntry.arguments?.getString("noteId") ?: ""
                NoteEditorScreen(
                    noteId = id,
                    onBack = { navController.popBackStack() },
                )
            }
            composable("meditate") {
                MeditateSelectScreen(
                    onBack = { navController.popBackStack() },
                    onStartMeditation = { id -> navController.navigate("breathing/$id") },
                )
            }
            composable("breathing/{meditationId}") { backStackEntry ->
                val id = backStackEntry.arguments?.getString("meditationId") ?: ""
                BreathingScreen(
                    meditationId = id,
                    onDone = { navController.popBackStack("home", inclusive = false) },
                    onBack = { navController.popBackStack() },
                    onWriteNote = { navController.navigate("newNote") },
                )
            }
        }
    }
}

/** Bottom-bar tabs, mirroring the iOS TabDestination set (home, notes, meditations). */
private data class TabItem(val route: String, val labelResourceId: Int, val icon: ImageVector)

private val TabBarItems = listOf(
    TabItem("home", R.string.home, Icons.Filled.Home),
    TabItem("notes", R.string.notes, Icons.AutoMirrored.Filled.Notes),
    TabItem("meditate", R.string.meditate, Icons.Filled.SelfImprovement),
)

/** Tab roots only: pushed screens (settings, breathing, editor) go full-screen. */
private val TabBarRoutes = TabBarItems.map { it.route }.toSet()

/** Placeholder body for not-yet-ported destinations. Replaced per screen. */
@Composable
private fun PlaceholderScreen(title: String) {
    Box(
        Modifier
            .fillMaxSize()
            .background(MnTheme.background),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            title,
            color = MnTheme.textPrimary,
            style = MaterialTheme.typography.titleLarge,
        )
    }
}