package com.mn.android.domain.subscription

/**
 * A typed failure of a subscription operation.
 *
 * Kotlin mirror of `SubscriptionOperationError` in
 * `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/SubscriptionOperationError.swift`.
 * The same five cases, so both platforms report the same situation the same
 * way and the UI can map them to the same messages.
 *
 * A sealed class rather than an enum: Kotlin can only throw a `Throwable`,
 * and an enum cannot extend one. Each case is an object, so the cases are
 * compared by identity.
 */
sealed class SubscriptionOperationError(message: String) : Exception(message) {

    /** No billing provider configured (missing key, or the SDK never started). */
    object NotConfigured : SubscriptionOperationError("notConfigured")

    /** The offerings could not be read. */
    object LoadFailed : SubscriptionOperationError("loadFailed")

    /** The purchase did not go through. */
    object PurchaseFailed : SubscriptionOperationError("purchaseFailed")

    /** The restore did not go through. */
    object RestoreFailed : SubscriptionOperationError("restoreFailed")

    /** The user closed the billing sheet. */
    object Cancelled : SubscriptionOperationError("cancelled")
}
