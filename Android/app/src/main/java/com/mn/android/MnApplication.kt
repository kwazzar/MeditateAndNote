package com.mn.android

import android.app.Application
import com.mn.android.application.analytics.StreakEvents
import com.mn.android.data.SharedPrefsSubscriptionCache
import com.mn.android.data.StreakHeaderSource
import com.mn.android.data.StreakSnapshotStore
import com.mn.android.domain.events.DomainEvent
import com.mn.android.domain.events.DomainEventBus
import com.mn.android.domain.subscription.Entitlement
import com.mn.android.infrastructure.analytics.AnalyticsEventMapper
import com.mn.android.infrastructure.analytics.AnalyticsUserProperties
import com.mn.android.infrastructure.analytics.AppAnalytics
import com.mn.android.infrastructure.persistence.local.settings.OnboardingStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MnApplication : Application() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        AppAnalytics.init(this)
        OnboardingStore.configure(this)
        StreakSnapshotStore.configure(this)
        setInitialUserProperties()
        scope.launch {
            setStreakBucketUserProperty()
            StreakEvents.sync()
            DomainEventBus.events.collect { event ->
                AnalyticsEventMapper.from(event)?.let(AppAnalytics::log)
                updateUserProperties(event)
            }
        }
    }

    private fun setInitialUserProperties() {
        AppAnalytics.setUserProperty(
            AnalyticsUserProperties.onboardingCompleted(OnboardingStore.hasCompletedOnboarding),
            AnalyticsUserProperties.ONBOARDING_COMPLETED,
        )

        val cachedStatus = SharedPrefsSubscriptionCache(this).load()
        AppAnalytics.setUserProperty(
            AnalyticsUserProperties.premiumStatus(cachedStatus?.isActive(Entitlement.PRO) == true),
            AnalyticsUserProperties.PREMIUM_STATUS,
        )
    }

    /** The streak lives in the Swift domain; the header source is the reader. */
    private suspend fun setStreakBucketUserProperty() {
        runCatching {
            val streak = StreakHeaderSource.readHeader().currentStreak
            AppAnalytics.setUserProperty(
                AnalyticsUserProperties.streakBucket(streak),
                AnalyticsUserProperties.STREAK_BUCKET,
            )
        }
    }

    private fun updateUserProperties(event: DomainEvent) {
        when (event) {
            is DomainEvent.SubscriptionChanged ->
                AppAnalytics.setUserProperty(
                    AnalyticsUserProperties.premiumStatus(event.isPremium),
                    AnalyticsUserProperties.PREMIUM_STATUS,
                )
            is DomainEvent.StreakExtended ->
                AppAnalytics.setUserProperty(
                    AnalyticsUserProperties.streakBucket(event.currentDays),
                    AnalyticsUserProperties.STREAK_BUCKET,
                )
            is DomainEvent.StreakBroken ->
                AppAnalytics.setUserProperty(
                    AnalyticsUserProperties.streakBucket(0),
                    AnalyticsUserProperties.STREAK_BUCKET,
                )
            else -> Unit
        }
    }
}
