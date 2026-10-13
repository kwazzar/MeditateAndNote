package com.mn.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
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
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import kotlinx.coroutines.delay
import com.mn.android.R
import com.mn.android.data.AnimationSettings
import com.mn.android.data.MeditationSelection
import com.mn.android.data.NoteBlobStore
import com.mn.android.data.OnboardingStore
import com.mn.android.data.SharedPrefsReminderSettingsStore
import com.mn.android.data.SoundSettings
import com.mn.android.data.StreakSnapshotStore
import com.mn.android.notifications.ReminderScheduler
import com.mn.android.sound.SoundPlayer
import com.mn.android.ui.home.HomeScreen
import com.mn.android.ui.launch.LoadingScreen
import com.mn.android.ui.settings.SettingsScreen
import com.mn.android.ui.meditate.BreathingScreen
import com.mn.android.ui.meditate.MeditateSelectScreen
import com.mn.android.ui.notes.NoteEditorScreen
import com.mn.android.ui.notes.NoteMenuScreen
import com.mn.android.ui.onboarding.OnboardingScreen
import com.mn.android.ui.streak.StreakDetailScreen
import com.mn.android.ui.theme.MnThemeProvider
import com.mn.android.ui.theme.MnTheme
import com.mn.android.ui.theme.rememberMnThemeManager

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

        setContent {
            val themeManager = rememberMnThemeManager()
            MaterialTheme(
                colorScheme = if (themeManager.theme.isDark) darkColorScheme() else lightColorScheme(),
            ) {
                MnThemeProvider(themeManager) {
                    // System-bar icon appearance follows the theme: light icons on
                    // dark themes, dark icons on light ones. Re-applied per theme
                    // switch; scrim is transparent so the root background shows.
                    val colors = MnTheme.colors
                    LaunchedEffect(colors.isDark) {
                        enableEdgeToEdge(
                            statusBarStyle = systemBarStyle(colors.isDark),
                            navigationBarStyle = systemBarStyle(colors.isDark),
                        )
                    }
                    MnNav()
                }
            }
        }
    }
}

private fun systemBarStyle(isDark: Boolean): SystemBarStyle =
    if (isDark) SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
    else SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT)

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
    MeditationSelection.configure(LocalContext.current)
    SoundSettings.configure(LocalContext.current)
    SoundPlayer.configure(LocalContext.current)
    AnimationSettings.configure(LocalContext.current)
    // Re-assert the pending reminder alarms on every launch: idempotent, and
    // covers anything the boot receiver missed (e.g. updated app process).
    ReminderScheduler.reschedule(LocalContext.current)

    val navController = rememberNavController()
    val startDestination =
        if (OnboardingStore.hasCompletedOnboarding) "home" else "onboarding"

    // Launch loader: shown over onboarding/tabs for 1800 ms, then fades out —
    // mirrors `RootContainer.scheduleLaunchDismissal` on iOS.
    var showsLaunch by remember { mutableStateOf(true) }
    LaunchedEffect(Unit) {
        delay(1800)
        showsLaunch = false
    }

    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route

    Box(Modifier.fillMaxSize()) {
        Scaffold(
        containerColor = MnTheme.background,
        bottomBar = {
            if (currentRoute in TabBarRoutes) {
                // iOS CustomTabBar container: maxWidth 480 in landscape,
                // centered (RootContainer.mainTabBar).
                val landscape = LocalConfiguration.current.orientation ==
                    android.content.res.Configuration.ORIENTATION_LANDSCAPE
                Box(
                    if (landscape) Modifier.fillMaxWidth() else Modifier
                ) {
                    NavigationBar(
                        containerColor = MnTheme.background,
                        tonalElevation = 0.dp,
                        modifier = if (landscape) {
                            Modifier
                                .align(Alignment.Center)
                                .width(480.dp)
                        } else Modifier,
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
                                    selectedIconColor = MnTheme.accentColor,
                                    selectedTextColor = MnTheme.accentColor,
                                    unselectedIconColor = MnTheme.textSecondary,
                                    unselectedTextColor = MnTheme.textSecondary,
                                    indicatorColor = MnTheme.accentColor.copy(alpha = 0.12f),
                                ),
                            )
                        }
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
                    onMeditate = {
                        // iOS MainView starts the last-picked meditation directly;
                        // the Meditations tab is where you change it.
                        val last = MeditationSelection.lastSelectedId
                        if (last != null) navController.navigate("breathing/$last")
                        else navController.navigate("meditate")
                    },
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
            composable("streakDetail") {
                StreakDetailScreen(
                    onBack = { navController.popBackStack() },
                    onStartMeditation = { navController.navigate("meditate") },
                    onWriteNote = { navController.navigate("newNote") },
                )
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

        AnimatedVisibility(
            visible = showsLaunch,
            enter = fadeIn(),
            exit = fadeOut(tween(450)),
        ) {
            LoadingScreen()
        }
    }
}

/** Bottom-bar tabs, mirroring the iOS `CustomTabBar` order: Notes, Home, Meditations. */
private data class TabItem(val route: String, val labelResourceId: Int, val icon: ImageVector)

private val TabBarItems = listOf(
    TabItem("notes", R.string.notes, Icons.AutoMirrored.Filled.Notes),
    TabItem("home", R.string.home, Icons.Filled.Home),
    TabItem("meditate", R.string.meditations, Icons.Filled.SelfImprovement),
)

/** Tab roots only: pushed screens (settings, breathing, editor) go full-screen. */
private val TabBarRoutes = TabBarItems.map { it.route }.toSet()

