package com.mn.android.domain.subscription

/**
 * Write side of subscriptions, backed by a payment provider (RevenueCat).
 * These calls are the only transitions that may grant an entitlement.
 *
 * Kotlin mirror of `SubscriptionManaging` in
 * `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/SubscriptionManaging.swift`.
 *
 * The provider types stay behind the implementation: the UI depends on this
 * contract, never on RevenueCat.
 */
interface SubscriptionManaging {

    /** False when no provider key is configured - every call then fails with
     *  [SubscriptionOperationError.NotConfigured] instead of reaching a
     *  half-initialised billing client. */
    val isConfigured: Boolean

    /** The packages on offer, in the order the provider lists them. */
    suspend fun offerings(): List<SubscriptionOffering>

    /** Buys [product]; the returned status is what the provider verified. */
    suspend fun purchase(product: SubscriptionPackage): SubscriptionStatus

    /** Restores the purchases of the current Play Store account. */
    suspend fun restore(): SubscriptionStatus

    /**
     * The provider's current status, or `null` when it could not be
     * determined (offline with no cached data). `null` must never be treated
     * as "free" - callers keep their last known status.
     */
    suspend fun refresh(): SubscriptionStatus?
}
