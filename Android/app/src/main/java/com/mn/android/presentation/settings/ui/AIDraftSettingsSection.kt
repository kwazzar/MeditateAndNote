package com.mn.android.presentation.settings.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.mn.android.R
import com.mn.android.data.AIDraftSettingsStore
import com.mn.android.presentation.theme.ui.MnTheme

/**
 * Where the AI draft provider is configured.
 *
 * Two ways to answer a draft: the hosted provider (our proxy, which carries
 * the provider key) or an endpoint of the user's own. Both send the note
 * text off the device, so the section says so - the switch is the user's
 * choice of who receives it, not a promise of privacy.
 */
@Composable
internal fun AIDraftSettingsSection() {
    var useHosted by remember { mutableStateOf(AIDraftSettingsStore.useHostedProvider()) }
    var endpoint by remember { mutableStateOf(AIDraftSettingsStore.userEndpoint()) }
    var model by remember { mutableStateOf(AIDraftSettingsStore.model()) }
    var apiKey by remember { mutableStateOf(AIDraftSettingsStore.apiKey().orEmpty()) }
    var saved by remember { mutableStateOf(false) }

    SectionCard {
        SectionHeader(stringResource(R.string.ai_settings_title), Icons.Filled.AutoAwesome)
        Text(
            stringResource(R.string.ai_settings_summary),
            color = MnTheme.textSecondary,
            style = MaterialTheme.typography.bodySmall,
        )
        Text(
            stringResource(R.string.ai_settings_privacy),
            color = MnTheme.textSecondary,
            style = MaterialTheme.typography.bodySmall,
        )
        Spacer(Modifier.height(8.dp))
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.ai_settings_use_hosted),
                color = MnTheme.textPrimary,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f),
            )
            Switch(
                checked = useHosted,
                onCheckedChange = { useHosted = it; saved = false },
                colors = SwitchDefaults.colors(
                    checkedTrackColor = MnTheme.streakActiveMeditation,
                    checkedThumbColor = MnTheme.buttonText,
                ),
            )
        }

        if (useHosted) {
            Spacer(Modifier.height(8.dp))
            Text(
                AIDraftSettingsStore.hostedEndpoint(),
                color = MnTheme.textSecondary,
                style = MaterialTheme.typography.bodySmall,
            )
        } else {
            Spacer(Modifier.height(8.dp))
            AIDraftField(
                value = endpoint,
                label = stringResource(R.string.ai_settings_endpoint),
                onValueChange = { endpoint = it; saved = false },
            )
            AIDraftField(
                value = model,
                label = stringResource(R.string.ai_settings_model),
                onValueChange = { model = it; saved = false },
            )
            AIDraftField(
                value = apiKey,
                label = stringResource(R.string.ai_settings_api_key),
                onValueChange = { apiKey = it; saved = false },
                isSecret = true,
            )
        }

        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
        ) {
            TextButton(
                onClick = {
                    AIDraftSettingsStore.setUseHostedProvider(useHosted)
                    if (!useHosted) {
                        AIDraftSettingsStore.save(endpoint, model, apiKey)
                    }
                    saved = true
                },
            ) {
                Text(
                    stringResource(R.string.ai_settings_save),
                    color = MnTheme.streakActiveMeditation,
                )
            }
        }
        if (saved) {
            Text(
                stringResource(R.string.ai_settings_saved),
                color = MnTheme.textSecondary,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Composable
private fun AIDraftField(
    value: String,
    label: String,
    onValueChange: (String) -> Unit,
    isSecret: Boolean = false,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        singleLine = true,
        visualTransformation = if (isSecret) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = MnTheme.textPrimary,
            unfocusedTextColor = MnTheme.textPrimary,
            focusedBorderColor = Color.Transparent,
            unfocusedBorderColor = Color.Transparent,
            focusedContainerColor = MnTheme.background,
            unfocusedContainerColor = MnTheme.background,
        ),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
    )
}
