package com.mn.android.ui.onboarding

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Notes
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mn.android.ui.theme.MnTheme
import kotlinx.coroutines.launch
import kotlin.random.Random

/**
 * The onboarding flow, ported from `OnboardingView` + `OnboardingPageView`.
 *
 * Structure is a translation rather than a redesign: skip top-right, paged
 * slides, dot indicator, one capsule footer button that reads "Next" until the
 * last slide and "Start" there — same copy, same order, same padding rhythm.
 *
 * There is no Kotlin `ViewModel`. `OnboardingViewModel` on iOS holds a page
 * index, two navigation guards and a store call; that has no invariant to
 * protect, so hoisting it into a class would be ceremony. The screen keeps the
 * index in pager state and writes the flag through [OnboardingStore]. A screen
 * gets a `ViewModel` when it grows real logic, not before.
 */
@Composable
fun OnboardingScreen(onCompleted: () -> Unit) {
    val pages = remember { appSlides }
    val pagerState = rememberPagerState { pages.size }
    val scope = rememberCoroutineScope()
    val isOnLastPage = pagerState.currentPage >= pages.lastIndex

    Box(
        Modifier
            .fillMaxSize()
            .background(MnTheme.background)
    ) {
        Starfield(Modifier.fillMaxSize())

        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
        ) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(end = 20.dp, top = 12.dp),
                horizontalArrangement = Arrangement.End,
            ) {
                TextButton(onClick = onCompleted) {
                    Text(
                        "Skip",
                        color = MnTheme.textSecondary,
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
            }

            HorizontalPager(
                state = pagerState,
                modifier = Modifier.weight(1f),
            ) { page ->
                SlideContent(pages[page])
            }

            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(top = 4.dp),
            ) {
                repeat(pages.size) { index ->
                    val isActive = index == pagerState.currentPage
                    Box(
                        Modifier
                            .size(if (isActive) 10.dp else 8.dp)
                            .clip(CircleShape)
                            .background(if (isActive) MnTheme.iconPrimary else MnTheme.divider)
                    )
                }
            }

            Spacer(Modifier.height(24.dp))

            Button(
                onClick = {
                    if (isOnLastPage) onCompleted()
                    else scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
                },
                shape = RoundedCornerShape(percent = 50),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MnTheme.accentButton,
                    contentColor = MnTheme.buttonText,
                ),
                contentPadding = PaddingValues(vertical = 16.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp),
            ) {
                Text(
                    if (isOnLastPage) "Start" else "Next",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
            }

            Spacer(Modifier.height(40.dp))
        }
    }
}

/// One slide: artwork placeholder + title + description.
@Composable
private fun SlideContent(page: Slide) {
    Column(
        Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))

        // 220dp reserves the height SwiftUI's artwork frame asks for; the icon
        // itself is 100dp, matching `.font(.system(size: 100, weight: .thin))`.
        Box(
            Modifier.height(220.dp),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = page.icon,
                contentDescription = null,
                tint = MnTheme.iconPrimary,
                modifier = Modifier.size(100.dp),
            )
        }

        Spacer(Modifier.height(20.dp))

        Text(
            page.title,
            color = MnTheme.textPrimary,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
        )

        Spacer(Modifier.height(20.dp))

        Text(
            page.subtitle,
            color = MnTheme.textSecondary,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 8.dp),
        )

        Spacer(Modifier.weight(1f))
    }
}

/**
 * `DarkZenStarfield`: 40 fixed-size dots at white 0.08.
 *
 * Positions are generated once per composition, the same way the SwiftUI
 * version generates them in `onAppear` and not on every `body` call — otherwise
 * the stars would jump on each recomposition.
 */
@Composable
private fun Starfield(modifier: Modifier = Modifier) {
    val stars = remember {
        List(40) { Random.nextFloat() to Random.nextFloat() }
    }
    Canvas(modifier) {
        stars.forEach { (x, y) ->
            drawCircle(
                color = MnTheme.star,
                radius = 1.dp.toPx(),
                center = Offset(x * size.width, y * size.height),
            )
        }
    }
}

/// A single onboarding slide: content only, no layout.
private data class Slide(
    val title: String,
    val subtitle: String,
    val icon: ImageVector,
)

/**
 * Default slides — the same three as `OnboardingPage.appSlides`, same copy,
 * same order, so the two platforms stay aligned until real artwork lands.
 *
 * SF Symbol -> Material icon, since Material has no exact counterpart for two
 * of the three: `leaf` -> `Eco`, `note.text` -> `Notes`, `flame` -> `Whatshot`.
 * Placeholders, as in the Swift file.
 */
private val appSlides = listOf(
    Slide(
        title = "Meditations",
        subtitle = "Focus on your breathing with guided sessions and soothing animations.",
        icon = Icons.Filled.Eco,
    ),
    Slide(
        title = "Notes",
        subtitle = "Capture your thoughts right after a session, while they are still fresh.",
        icon = Icons.AutoMirrored.Filled.Notes,
    ),
    Slide(
        title = "Streak tracking",
        subtitle = "Build a habit: a daily meditation plus a note keeps your streak alive.",
        icon = Icons.Filled.Whatshot,
    ),
)
