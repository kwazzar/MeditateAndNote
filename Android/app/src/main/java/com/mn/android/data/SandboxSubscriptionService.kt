package com.mn.android.data

import com.mn.android.domain.subscription.Entitlement
import com.mn.android.domain.subscription.SubscriptionManaging
import com.mn.android.domain.subscription.SubscriptionOffering
import com.mn.android.domain.subscription.SubscriptionPackage
import com.mn.android.domain.subscription.SubscriptionStatus

/**
 * A local stand-in for the billing provider.
 *
 * Debug builds without a RevenueCat key use this so the paywall, the Pro
 * gates and the AI-draft allowance can be tested without a Play Console
 * account, a real product and a real payment. A release build never gets it:
 * with no key there the paywall reports "unavailable" instead of handing out
 * a free lifetime unlock.
 *
 * It behaves like a lifetime purchase: buying grants `pro`, restoring
 * pretends the store still knows about it, and the status survives restarts
 * through the same cache a real purchase uses.
 */
class SandboxSubscriptionService : SubscriptionManaging {

    override val isConfigured: Boolean = true

    private var status: SubscriptionStatus = SubscriptionStatus.NONE

    override suspend fun offerings(): List<SubscriptionOffering> = listOf(
        SubscriptionOffering(
            id = SANDBOX_OFFERING_ID,
            title = "Sandbox",
            packages = listOf(
                SubscriptionPackage(
                    id = SANDBOX_PACKAGE_ID,
                    // Marked as a sandbox so nobody mistakes it for the real
                    // price of a real product.
                    title = "Premium Lifetime (sandbox)",
                    priceString = "8.99 US$",
                )
            ),
        )
    )

    override suspend fun purchase(product: SubscriptionPackage): SubscriptionStatus {
        status = proStatus(product.id)
        return status
    }

    override suspend fun restore(): SubscriptionStatus {
        status = proStatus(SANDBOX_PACKAGE_ID)
        return status
    }

    override suspend fun refresh(): SubscriptionStatus? = status

    private fun proStatus(productId: String) = SubscriptionStatus(
        activeEntitlements = setOf(Entitlement.PRO),
        willRenew = false,
        productIdentifier = productId,
    )

    private companion object {
        const val SANDBOX_OFFERING_ID = "sandbox"
        const val SANDBOX_PACKAGE_ID = "sandbox_lifetime"
    }
}
