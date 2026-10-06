package com.mn.android.ui.home

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.mn.android.ui.theme.MnTheme

/**
 * Placeholder destination the onboarding flow navigates to.
 *
 * Deliberately empty: the real tab shell comes with the first screen that has
 * data behind it. What this proves now is that the navigation graph, the start
 * destination switch and the completed-onboarding flag all work end to end.
 */
@Composable
fun HomeScreen() {
    Box(
        Modifier
            .fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            "Meditate and Note",
            color = MnTheme.textPrimary,
            style = MaterialTheme.typography.headlineSmall,
        )
    }
}
