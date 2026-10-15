package com.mn.android.presentation.launch.ui

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.presentation.theme.ui.MnBackground
import com.mn.android.presentation.theme.ui.MnTheme
import com.mn.android.presentation.theme.ui.MeditateHero

/**
 * Port of iOS `LoadingScreenView`: themed full-screen launch loader with a
 * breathing hero centred exactly where the Home meditate button sits, and
 * "Meditate & Note" + a spinner near the bottom.
 *
 * Purely presentational — the host fades it out (MainActivity keeps it for
 * 1800 ms, matching `RootContainer.scheduleLaunchDismissal`).
 */
@Composable
fun LoadingScreen(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "launch")
    val breathing by transition.animateFloat(
        initialValue = 0.96f,
        targetValue = 1.06f,
        animationSpec = infiniteRepeatable(
            animation = tween(2400),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "breathing",
    )

    Box(modifier.fillMaxSize()) {
        MnBackground()

        MeditateHero(
            modifier = Modifier.align(Alignment.Center),
            scale = breathing,
        )

        Column(
            Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 44.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                "Meditate & Note",
                color = MnTheme.textPrimary,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(12.dp))
            CircularProgressIndicator(
                color = MnTheme.accentColor,
                strokeWidth = 3.dp,
                modifier = Modifier.size(28.dp),
            )
        }
    }
}

@Preview
@Composable
private fun LoadingScreenPreview() {
    LoadingScreen()
}
