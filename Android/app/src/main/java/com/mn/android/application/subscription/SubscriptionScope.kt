package com.mn.android.application.subscription

import android.content.Context
import com.mn.android.BuildConfig
import com.mn.android.data.RevenueCatPurchasesService
import com.mn.android.data.SandboxSubscriptionService
import com.mn.android.data.SharedPrefsSubscriptionCache
import com.mn.android.domain.subscription.SubscriptionManaging

/**
 * Owns the [SubscriptionManager] and its production dependencies
 * (the RevenueCat service + the SharedPreferences cache).
 *
 * The Android counterpart of iOS `SubscriptionScope`
 * (`MeditateAndNote/AppContainer/SubscriptionScope.swift`). The manager is
 * memoized so the whole app shares one status - the theme picker, the settings
 * card and the paywall have to agree on whether the user is pro.
 */
object SubscriptionScope {

    @Volatile
    private var instance: SubscriptionManager? = null

    fun manager(context: Context): SubscriptionManager =
        instance ?: synchronized(this) {
            instance ?: create(context.applicationContext).also { instance = it }
        }

    /**
     * Test seam: forget the manager and the cached status, so the next
     * [manager] call starts from "no entitlement" again.
     */
    fun reset(context: Context) {
        synchronized(this) { instance = null }
        SharedPrefsSubscriptionCache(context.applicationContext).clear()
    }

    private fun create(context: Context) = SubscriptionManager(
        service = service(context),
        cache = SharedPrefsSubscriptionCache(context),
    )

    /**
     * The provider the app talks to.
     *
     * A RevenueCat key → the real provider. A debug build without one → the
     * sandbox, so the paywall and the Pro gates can be tested without a Play
     * Console account. A release build without a key → the real (unconfigured)
     * provider, which reports "subscriptions unavailable" rather than handing
     * out a free lifetime unlock.
     */
    private fun service(context: Context): SubscriptionManaging {
        val key = BuildConfig.REVENUECAT_API_KEY
        return when {
            key.isNotEmpty() -> RevenueCatPurchasesService(context, apiKey = key)
            BuildConfig.DEBUG -> SandboxSubscriptionService()
            else -> RevenueCatPurchasesService(context, apiKey = key)
        }
    }
}
