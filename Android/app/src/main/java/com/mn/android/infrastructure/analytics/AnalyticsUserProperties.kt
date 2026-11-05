package com.mn.android.infrastructure.analytics

/**
 * The user-property values the app reports to the analytics backend.
 *
 * `premium_status`, `onboarding_completed` and `streak_bucket` are the three
 * properties the dashboards slice by; their values are fixed strings so both
 * platforms report the same buckets.
 */
object AnalyticsUserProperties {

    const val ONBOARDING_COMPLETED = "onboarding_completed"
    const val PREMIUM_STATUS = "premium_status"
    const val STREAK_BUCKET = "streak_bucket"

    fun premiumStatus(isPremium: Boolean): String = if (isPremium) "pro" else "free"

    fun onboardingCompleted(hasCompleted: Boolean): String =
        if (hasCompleted) "true" else "false"

    fun streakBucket(days: Int): String = when {
        days <= 0 -> "0"
        days <= 3 -> "1-3"
        days <= 7 -> "4-7"
        days <= 14 -> "8-14"
        else -> "15+"
    }
}
