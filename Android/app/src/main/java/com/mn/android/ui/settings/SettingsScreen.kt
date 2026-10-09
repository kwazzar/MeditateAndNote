package com.mn.android.ui.settings

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.text.format.DateFormat
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.WavingHand
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.mn.android.R
import com.mn.android.data.SharedPrefsReminderSettingsStore
import com.mn.android.ui.theme.MnTheme
import android.Manifest
import android.content.pm.PackageManager

/** Mirrors the iOS weekdaySymbols order: index = weekday - 1, Sunday = 1. */
private val weekdaySymbols = listOf("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    onShowOnboarding: () -> Unit,
) {
    val context = LocalContext.current

    val initial = remember { SharedPrefsReminderSettingsStore.load() }
    var enabled by remember { mutableStateOf(initial[0] == 1L) }
    var hour by remember { mutableStateOf(initial.getOrElse(1) { 20L }.toInt()) }
    var minute by remember { mutableStateOf(initial.getOrElse(2) { 0L }.toInt()) }
    var weekdays by remember { mutableStateOf(initial.drop(3).map { it.toInt() }.toSet()) }
    var showTimePicker by remember { mutableStateOf(false) }

    val hasPermission =
        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    var permissionRequested by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { }

    fun save() {
        SharedPrefsReminderSettingsStore.save(
            enabled,
            hour,
            minute,
            weekdays.sorted().map { it.toLong() }.toLongArray(),
        )
    }

    Column(Modifier.fillMaxSize().background(MnTheme.background).padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back), tint = MnTheme.textPrimary)
            }
            Text(
                stringResource(R.string.settings),
                color = MnTheme.textPrimary,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
            )
        }

        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            // Reminders — mirror of ReminderSettingsSection. Scheduling
            // (AlarmManager) is not wired yet; this persists the settings only.
            SectionCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SectionHeader(stringResource(R.string.reminders), Icons.Filled.Notifications, Modifier.weight(1f))
                    Switch(
                        checked = enabled,
                        onCheckedChange = { newValue ->
                            if (newValue && !hasPermission) {
                                permissionRequested = true
                                permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                            }
                            enabled = newValue
                            save()
                        },
                        colors = SwitchDefaults.colors(
                            checkedTrackColor = MnTheme.streakActiveMeditation,
                            checkedThumbColor = MnTheme.buttonText,
                        ),
                    )
                }

                if (enabled) {
                    Spacer(Modifier.height(12.dp))
                    Row(
                        Modifier.fillMaxWidth().clickable { showTimePicker = true },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            stringResource(R.string.reminder_time),
                            color = MnTheme.textSecondary,
                            style = MaterialTheme.typography.labelLarge,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            String.format("%02d:%02d", hour, minute),
                            color = MnTheme.textPrimary,
                            style = MaterialTheme.typography.titleMedium,
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    Text(
                        stringResource(R.string.repeat_on),
                        color = MnTheme.textSecondary,
                        style = MaterialTheme.typography.labelLarge,
                    )
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        (1..7).forEach { weekday ->
                            WeekdayChip(
                                label = weekdaySymbols[weekday - 1],
                                selected = weekday in weekdays,
                                onClick = {
                                    if (weekday in weekdays) {
                                        if (weekdays.size > 1) weekdays = weekdays - weekday
                                    } else {
                                        weekdays = weekdays + weekday
                                    }
                                    save()
                                },
                                modifier = Modifier.weight(1f),
                            )
                        }
                    }
                    if (!hasPermission && permissionRequested) {
                        Spacer(Modifier.height(12.dp))
                        PermissionBanner(
                            onAllow = {
                                if (shouldShowDenied(context)) {
                                    permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                                } else {
                                    openAppSettings(context)
                                }
                            },
                        )
                    }
                }
            }

            if (isDebuggable(context)) {
                SectionCard {
                    Row(
                        Modifier.fillMaxWidth().clickable(onClick = onShowOnboarding),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            Icons.Filled.WavingHand,
                            contentDescription = null,
                            tint = MnTheme.streakActiveMeditation,
                        )
                        Spacer(Modifier.width(12.dp))
                        Text(
                            stringResource(R.string.show_onboarding_again),
                            color = MnTheme.textPrimary,
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.weight(1f),
                        )
                        Icon(
                            Icons.Filled.Build,
                            contentDescription = null,
                            tint = MnTheme.textSecondary,
                            modifier = Modifier.size(16.dp),
                        )
                    }
                }
            }
        }
    }

    if (showTimePicker) {
        val timeState = rememberTimePickerState(initialHour = hour, initialMinute = minute, is24Hour = DateFormat.is24HourFormat(context))
        AlertDialog(
            onDismissRequest = { showTimePicker = false },
            containerColor = MnTheme.background,
            title = { Text(stringResource(R.string.reminder_time), color = MnTheme.textPrimary) },
            text = { TimePicker(state = timeState) },
            confirmButton = {
                TextButton(onClick = {
                    hour = timeState.hour
                    minute = timeState.minute
                    showTimePicker = false
                    save()
                }) {
                    Text(stringResource(R.string.ok), color = MnTheme.streakActiveMeditation)
                }
            },
            dismissButton = {
                TextButton(onClick = { showTimePicker = false }) {
                    Text(stringResource(R.string.cancel), color = MnTheme.textSecondary)
                }
            },
        )
    }
}

@Composable
private fun SectionCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth()
            .background(MnTheme.cardBackground, RoundedCornerShape(16.dp))
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
        content = content,
    )
}

@Composable
private fun SectionHeader(title: String, icon: ImageVector, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = MnTheme.streakActiveMeditation, modifier = Modifier.size(15.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, color = MnTheme.textPrimary, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun WeekdayChip(label: String, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Text(
        label,
        color = if (selected) MnTheme.buttonText else MnTheme.textSecondary,
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.SemiBold,
        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        modifier = modifier
            .background(
                if (selected) MnTheme.streakActiveMeditation else MnTheme.divider,
                RoundedCornerShape(8.dp),
            )
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
    )
}

@Composable
private fun PermissionBanner(onAllow: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Notifications, contentDescription = null, tint = MnTheme.streakIndicator, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(8.dp))
        Text(
            stringResource(R.string.allow_notifications_message),
            color = MnTheme.textSecondary,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(8.dp))
        Button(
            onClick = onAllow,
            colors = ButtonDefaults.buttonColors(containerColor = MnTheme.streakActiveMeditation),
        ) {
            Text(stringResource(R.string.allow), color = MnTheme.buttonText)
        }
    }
}

private fun isDebuggable(context: android.content.Context): Boolean =
    (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0

private fun shouldShowDenied(context: android.content.Context): Boolean {
    val activity = context as? android.app.Activity ?: return true
    return android.os.Build.VERSION.SDK_INT < 23 ||
        activity.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)
}

private fun openAppSettings(context: android.content.Context) {
    context.startActivity(
        Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", context.packageName, null),
        )
    )
}