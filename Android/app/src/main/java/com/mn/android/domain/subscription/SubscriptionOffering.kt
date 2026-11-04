package com.mn.android.domain.subscription

/**
 * A purchasable package within an offering.
 *
 * Kotlin mirror of `SubscriptionPackage` /
 * `SubscriptionOffering` in
 * `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/SubscriptionOffering.swift`.
 *
 * The billing provider's own types never reach the UI: the adapter maps them
 * to these value objects, so the paywall talks about ids, titles and prices
 * and nothing else.
 */
data class SubscriptionPackage(
    val id: String,
    val title: String,
    val priceString: String,
)

/** A billing offering with the packages it contains. */
data class SubscriptionOffering(
    val id: String,
    val title: String,
    val packages: List<SubscriptionPackage>,
)
