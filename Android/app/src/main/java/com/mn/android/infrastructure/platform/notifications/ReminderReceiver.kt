package com.mn.android.infrastructure.platform.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import com.mn.android.data.ReminderScheduleSource
import com.mn.android.data.reminder.JniReminderSettingsStore
import com.mn.android.domain.settings.ReminderScheduler

/**
 * Android counterpart of iOS `ReminderManager.reschedule()` +
 * `SystemNotificationScheduler`: cancels this app's pending reminder alarms,
 * then schedules the next 7 fire dates produced by Core's
 * `ReminderScheduleBuilder` (same math, same horizon as the iOS app).
 *
 * Fire dates are exact alarms; when the OS has not granted exact-alarm
 * scheduling (Android 12+ `SCHEDULE_EXACT_ALARM`), it falls back to
 * inexact ones — a late reminder beats none.
 */
object AndroidReminderScheduler : ReminderScheduler {

    /** `ReminderManager.notificationIDPrefix` + index — request codes 1000..1006. */
    private const val REQUEST_CODE_BASE = 1000
    const val HORIZON = 7

    @Volatile
    private var appContext: Context? = null

    fun configure(context: Context) {
        appContext = context.applicationContext
    }

    /** The port's way: the context the app configured at startup. */
    override fun reschedule() {
        val context = appContext ?: return
        reschedule(context)
    }

    fun reschedule(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val pending = (0 until HORIZON).map { index ->
            pendingIntent(context, index)
        }
        pending.forEach(alarmManager::cancel)

        val settings = JniReminderSettingsStore(context).load()
        if (!settings.enabled) return
        if (settings.weekdays.isEmpty()) return

        val fireDates = ReminderScheduleSource.nextFireDates(
            enabled = settings.enabled,
            hour = settings.hour,
            minute = settings.minute,
            weekdays = settings.weekdays,
            afterMillis = System.currentTimeMillis(),
            horizon = HORIZON,
        )
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
        fireDates.forEachIndexed { index, millis ->
            val intent = pending[index]
            if (canExact) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, millis, intent)
            } else {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, millis, intent)
            }
        }
    }

    fun pendingIntent(context: Context, index: Int): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_REMINDER_FIRE
            putExtra(ReminderReceiver.EXTRA_INDEX, index)
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_BASE + index,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

/**
 * Fires the streak reminder notification (iOS `notificationTitle` /
 * `notificationBody`) and reschedules the next horizon — iOS gets the same
 * from `UNCalendarNotificationTrigger` repeat semantics; Android alarms are
 * one-shot, so the receiver keeps the chain alive. Also handles reboot:
 * `BOOT_COMPLETED` clears every pending alarm, so it just reschedules.
 */
class ReminderReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_REMINDER_FIRE = "com.mn.android.REMINDER_FIRE"
        const val EXTRA_INDEX = "reminderIndex"

        /** iOS `ReminderManager.notificationTitle` / `notificationBody`. */
        private const val NOTIFICATION_TITLE = "Streak reminder"
        private const val NOTIFICATION_BODY =
            "Time to complete today's streak — meditate and write a quick note."
        private const val CHANNEL_ID = "streak_reminders"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            AndroidReminderScheduler.reschedule(context)
            return
        }
        if (intent.action != ACTION_REMINDER_FIRE) return

        notifyNow(context)
        AndroidReminderScheduler.reschedule(context)
    }

    private fun notifyNow(context: Context) {
        val manager = context.getSystemService(android.app.NotificationManager::class.java) ?: return
        val channel = android.app.NotificationChannel(
            CHANNEL_ID,
            "Streak reminders",
            android.app.NotificationManager.IMPORTANCE_DEFAULT,
        )
        manager.createNotificationChannel(channel)

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = android.app.Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(NOTIFICATION_TITLE)
            .setContentText(NOTIFICATION_BODY)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()
        manager.notify(1000, notification)
    }
}
