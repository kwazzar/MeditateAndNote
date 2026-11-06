package com.mn.android.presentation.paywall.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.mn.android.R
import com.mn.android.application.container.AppContainer
import com.mn.android.domain.subscription.SubscriptionPackage
import com.mn.android.presentation.paywall.viewmodel.PaywallError
import com.mn.android.presentation.paywall.viewmodel.PaywallViewModel
import com.mn.android.presentation.theme.ui.MnBackground
import com.mn.android.presentation.theme.ui.MnTheme

/**
 * Port of the iOS `PaywallView`
 * (`MeditateAndNote/Views/Paywall/PaywallView.swift`).
 *
 * The offer screen: the crown, the four benefits, the packages with their
 * Play prices, the Subscribe button, Restore and the legal links. RevenueCat
 * hosts no UI here - the prices come from the provider, the layout is ours.
 */
@Composable
fun PaywallScreen(onClose: () -> Unit) {
    val context = LocalContext.current
    val viewModel: PaywallViewModel = viewModel(
        factory = viewModelFactory {
            initializer { AppContainer.makePaywallViewModel(context) }
        }
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val isPremium by viewModel.isPremium.collectAsStateWithLifecycle()
    val uriHandler = LocalUriHandler.current

    LaunchedEffect(Unit) { viewModel.load() }
    // A purchase that succeeded must not leave the user on the offer screen.
    LaunchedEffect(isPremium) { if (isPremium) onClose() }

    Box(Modifier.fillMaxSize()) {
        MnBackground()
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(24.dp))

            Icon(
                Icons.Filled.WorkspacePremium,
                contentDescription = null,
                tint = MnTheme.streakActiveMeditation,
                modifier = Modifier.size(56.dp),
            )

            Spacer(Modifier.height(16.dp))

            Text(
                stringResource(R.string.paywall_title),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MnTheme.textPrimary,
            )
            Text(
                stringResource(R.string.paywall_subtitle),
                style = MaterialTheme.typography.bodyMedium,
                color = MnTheme.textSecondary,
            )

            Spacer(Modifier.height(24.dp))

            Benefits()

            Spacer(Modifier.height(24.dp))

            if (state.isLoading) {
                CircularProgressIndicator(color = MnTheme.streakActiveMeditation)
                Spacer(Modifier.height(12.dp))
            }

            state.packages.forEach { product ->
                PackageCard(
                    product = product,
                    selected = product.id == state.selectedPackageId,
                    onSelect = { viewModel.select(product) },
                )
                Spacer(Modifier.height(8.dp))
            }

            state.error?.let { error ->
                Text(
                    stringResource(error.messageRes()),
                    style = MaterialTheme.typography.bodySmall,
                    color = MnTheme.danger,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(8.dp))
            }

            Button(
                onClick = { viewModel.purchaseSelected() },
                enabled = !state.isLoading && state.selectedPackage != null,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MnTheme.streakActiveMeditation,
                    contentColor = MnTheme.buttonText,
                    disabledContainerColor = MnTheme.streakActiveMeditation.copy(alpha = 0.5f),
                    disabledContentColor = MnTheme.buttonText,
                ),
            ) {
                val price = state.selectedPackage?.priceString
                Text(
                    if (price != null) {
                        stringResource(R.string.paywall_subscribe_price, price)
                    } else {
                        stringResource(R.string.paywall_subscribe)
                    },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
            }

            TextButton(onClick = { viewModel.restore() }, enabled = !state.isLoading) {
                Text(
                    stringResource(R.string.paywall_restore),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MnTheme.textSecondary,
                )
            }

            Spacer(Modifier.height(8.dp))

            // Legal links - the same placeholders the iOS paywall uses until
            // the store metadata is attached.
            Text(
                text = stringResource(R.string.paywall_terms),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.clickable { uriHandler.openUri(TERMS_URL) },
            )
            Text(
                text = stringResource(R.string.paywall_privacy),
                style = MaterialTheme.typography.labelSmall,
                color = MnTheme.textSecondary,
                modifier = Modifier.clickable { uriHandler.openUri(PRIVACY_URL) },
            )

            TextButton(onClick = onClose) {
                Text(
                    stringResource(R.string.paywall_close),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MnTheme.textSecondary,
                )
            }
        }
    }
}

/** The four things the subscription unlocks, iOS `benefits` in order. */
@Composable
private fun Benefits() {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Benefit(Icons.Filled.Palette, stringResource(R.string.paywall_benefit_themes))
        Benefit(Icons.Filled.AutoAwesome, stringResource(R.string.paywall_benefit_ai))
        Benefit(Icons.Filled.ShowChart, stringResource(R.string.paywall_benefit_insights))
        Benefit(Icons.Filled.Cloud, stringResource(R.string.paywall_benefit_storage))
    }
}

@Composable
private fun Benefit(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            icon,
            contentDescription = null,
            tint = MnTheme.streakActiveMeditation,
            modifier = Modifier.size(20.dp),
        )
        Spacer(Modifier.size(12.dp))
        Text(
            text,
            style = MaterialTheme.typography.bodyLarge,
            color = MnTheme.textPrimary,
        )
    }
}

@Composable
private fun PackageCard(
    product: SubscriptionPackage,
    selected: Boolean,
    onSelect: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MnTheme.editorBackground)
            .clickable(onClick = onSelect)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            if (selected) Icons.Filled.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
            contentDescription = null,
            tint = MnTheme.streakActiveMeditation,
            modifier = Modifier.size(20.dp),
        )
        Spacer(Modifier.size(12.dp))
        Text(
            product.title,
            style = MaterialTheme.typography.bodyLarge,
            color = MnTheme.textPrimary,
            maxLines = 1,
            modifier = Modifier.weight(1f),
        )
        Text(
            product.priceString,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MnTheme.textPrimary,
        )
    }
}

private fun PaywallError.messageRes(): Int = when (this) {
    PaywallError.UNAVAILABLE -> R.string.paywall_error_unavailable
    PaywallError.LOAD_FAILED -> R.string.paywall_error_load
    PaywallError.PURCHASE_FAILED -> R.string.paywall_error_purchase
    PaywallError.RESTORE_FAILED -> R.string.paywall_error_restore
}

private const val TERMS_URL = "https://www.revenuecat.com/terms/"
private const val PRIVACY_URL = "https://www.revenuecat.com/privacy/"
