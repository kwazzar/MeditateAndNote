package com.mn.android.infrastructure.analytics

import android.os.Bundle
import com.google.firebase.analytics.FirebaseAnalytics

class FirebaseAnalyticsTracker(private val analytics: FirebaseAnalytics) {

    fun log(event: AnalyticsEvent) {
        val bundle = Bundle().apply {
            event.params.forEach { (key, value) ->
                when (value) {
                    is Int -> putInt(key, value)
                    is Long -> putLong(key, value)
                    is Double -> putDouble(key, value)
                    is Float -> putFloat(key, value)
                    is Boolean -> putBoolean(key, value)
                    else -> putString(key, value.toString())
                }
            }
        }
        analytics.logEvent(event.name, bundle)
    }

    fun trackScreen(name: String) {
        log(
            AnalyticsEvent(
                FirebaseAnalytics.Event.SCREEN_VIEW,
                mapOf(
                    FirebaseAnalytics.Param.SCREEN_NAME to name,
                    FirebaseAnalytics.Param.SCREEN_CLASS to name,
                ),
            )
        )
    }
}
