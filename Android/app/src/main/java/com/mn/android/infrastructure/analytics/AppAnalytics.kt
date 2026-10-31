package com.mn.android.infrastructure.analytics

import android.content.Context
import com.google.firebase.analytics.FirebaseAnalytics

/** Process-wide adapter, initialized once by [com.mn.android.MnApplication]. */
object AppAnalytics {
    @Volatile
    private var tracker: FirebaseAnalyticsTracker? = null

    fun init(context: Context) {
        tracker = FirebaseAnalyticsTracker(FirebaseAnalytics.getInstance(context))
    }

    fun log(event: AnalyticsEvent) {
        tracker?.log(event)
    }

    fun screen(name: String) {
        tracker?.trackScreen(name)
    }
}
