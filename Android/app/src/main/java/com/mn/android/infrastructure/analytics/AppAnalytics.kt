package com.mn.android.infrastructure.analytics

import android.content.Context
import com.google.firebase.analytics.FirebaseAnalytics

/** Process-wide adapter, initialized once by [com.mn.android.MnApplication]. */
object AppAnalytics {
    @Volatile
    private var tracker: FirebaseAnalyticsTracker? = null

    /**
     * Without a Firebase config the SDK has no default app and
     * `getInstance` throws, so the tracker stays null and analytics is a
     * no-op - the app still starts.
     */
    fun init(context: Context) {
        tracker = runCatching {
            FirebaseAnalyticsTracker(FirebaseAnalytics.getInstance(context))
        }.getOrNull()
    }

    fun log(event: AnalyticsEvent) {
        tracker?.log(event)
    }

    fun screen(name: String) {
        tracker?.trackScreen(name)
    }

    fun setUserProperty(value: String, name: String) {
        tracker?.setUserProperty(value, name)
    }
}
