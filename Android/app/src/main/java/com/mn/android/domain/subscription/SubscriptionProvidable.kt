package com.mn.android.domain.subscription

import kotlinx.coroutines.flow.StateFlow

/**
 * Read side of subscriptions: the current status a ViewModel can display.
 *
 * Kotlin mirror of `EntitlementProviding` in
 * `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/SubscriptionManaging.swift`.
 *
 * The status is a [StateFlow] rather than a plain value: Compose observes
 * it, so a purchase that happens while the paywall is open updates the UI
 * without a manual refresh.
 */
interface SubscriptionProvidable {
    val status: StateFlow<SubscriptionStatus>
    fun isActive(entitlement: Entitlement): Boolean
}

/**
 * Write side of subscriptions. These calls are the only transitions that may
 * grant an entitlement.
 *
 * Kotlin mirror of `SubscriptionManageable`.
 */
interface SubscriptionManageable {
    suspend fun offerings(): List<SubscriptionOffering>
    suspend fun purchase(product: SubscriptionPackage): SubscriptionStatus
    suspend fun restore(): SubscriptionStatus
    suspend fun refresh(): SubscriptionStatus?
}
