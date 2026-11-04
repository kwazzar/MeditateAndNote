package com.mn.android.domain.subscription

/**
 * Server-verified subscription state.
 *
 * Kotlin mirror of `SubscriptionStatus` in
 * `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/SubscriptionStatus.swift`.
 *
 * Only the billing provider may *grant* an entitlement; this value object
 * just carries what the provider reported. It is stored locally for the
 * offline launch, so the cache is a UX fast-path and never an authority.
 *
 * [expirationDate] is epoch milliseconds (the Swift side uses `Date`).
 */
data class SubscriptionStatus(
    val activeEntitlements: Set<Entitlement> = emptySet(),
    val expirationDate: Long? = null,
    val willRenew: Boolean = false,
    val productIdentifier: String? = null,
) {
    fun isActive(entitlement: Entitlement): Boolean = entitlement in activeEntitlements

    companion object {
        val NONE = SubscriptionStatus()
    }
}
