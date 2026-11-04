package com.mn.android.domain.subscription

/**
 * The paid features a user can unlock.
 *
 * Kotlin mirror of `Entitlement` in
 * `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/Entitlement.swift`.
 * This id is the app's own domain identity (it round-trips through the cache),
 * not the RevenueCat identifier - the provider maps its dashboard entitlement
 * onto it (see `RevenueCatPurchasesService.PREMIUM_ENTITLEMENT_ID`), exactly
 * like iOS `Config.proEntitlementID`.
 *
 * Why a mirror and not the Core type: Kotlin cannot implement a Swift
 * protocol, and the whole `Subscription*` silhouette is deliberately excluded
 * from the jextract bindings (see `Scripts/build-android.sh`), so the domain
 * of subscriptions cannot cross the JNI boundary.
 */
enum class Entitlement(val id: String) {
    PRO("pro"),
    ;

    companion object {
        fun fromId(id: String): Entitlement? = entries.firstOrNull { it.id == id }
    }
}
