package com.mn.android.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mn.android.ui.theme.MnTheme

/**
 * Placeholder destination the onboarding flow navigates to, now with the one
 * entry point that leads somewhere real: the meditation list. The tab shell
 * (streak / meditate / notes) comes when the screens behind the other tabs do.
 */
@Composable
fun HomeScreen(onMeditate: () -> Unit) {
    Column(
        Modifier
            .fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            "Meditate and Note",
            color = MnTheme.textPrimary,
            style = MaterialTheme.typography.headlineSmall,
        )
        Button(
            onClick = onMeditate,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 48.dp, vertical = 24.dp),
            colors = ButtonDefaults.buttonColors(containerColor = MnTheme.accentButton),
        ) {
            Text(
                "Meditate",
                color = MnTheme.buttonText,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}
