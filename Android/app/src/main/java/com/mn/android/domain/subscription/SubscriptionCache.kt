package com.mn.android.domain.subscription

/**
 * Last-known subscription status persisted locally for offline/fast startup.
 *
 * Kotlin mirror of `SubscriptionCache` in
 * `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/SubscriptionCache.swift`.
 *
 * The cache is NEVER an authority: it may seed the UI, but only a refresh
 * through [SubscriptionManaging] may grant or revoke an entitlement.
 */
interface SubscriptionCache {
    fun load(): SubscriptionStatus?
    fun save(status: SubscriptionStatus)
}
