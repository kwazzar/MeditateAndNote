package com.mn.android.data

import android.app.Activity
import android.content.Context
import com.mn.android.BuildConfig
import com.mn.android.domain.subscription.Entitlement
import com.mn.android.domain.subscription.SubscriptionCache
import com.mn.android.domain.subscription.SubscriptionManaging
import com.mn.android.domain.subscription.SubscriptionOperationError
import com.mn.android.domain.subscription.SubscriptionOffering
import com.mn.android.domain.subscription.SubscriptionPackage
import com.mn.android.domain.subscription.SubscriptionStatus
import com.mn.android.infrastructure.platform.billing.BillingActivity
import com.revenuecat.purchases.CacheFetchPolicy
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.PurchasesException
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.models.googleProduct

/**
 * Maps RevenueCat onto the domain [SubscriptionManaging] contract.
 *
 * The Android counterpart of iOS `RevenueCatPurchasesService`
 * (`MeditateAndNote/Services/Subscriptions/RevenueCatPurchasesService.swift`)
 * and the only file in the app that imports RevenueCat. The provider's own
 * types never reach the UI: `CustomerInfo`, `Offering` and `Package` are
 * mapped to domain value objects here.
 *
 * Trust model: this is the sole grant authority. Every answer comes from
 * `CustomerInfo` as reported by RevenueCat; the app never decides it is
 * entitled on its own.
 */
class RevenueCatPurchasesService(
    context: Context,
    private val apiKey: String = BuildConfig.REVENUECAT_API_KEY,
    private val entitlementId: String = PREMIUM_ENTITLEMENT_ID,
    private val activityProvider: () -> Activity? = { BillingActivity.current },
) : SubscriptionManaging {

    private val appContext = context.applicationContext

    override val isConfigured: Boolean
        get() = Purchases.isConfigured

    init {
        configureIfPossible()
    }

    /**
     * Starts the SDK once per process.
     *
     * An empty key leaves the SDK unconfigured, so every call degrades to
     * [SubscriptionOperationError.NotConfigured] instead of reaching a
     * half-initialised billing client. Configuring twice throws in the SDK,
     * hence the `isConfigured` guard.
     */
    private fun configureIfPossible() {
        if (apiKey.isEmpty() || Purchases.isConfigured) return
        runCatching {
            Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.INFO
            Purchases.configure(PurchasesConfiguration.Builder(appContext, apiKey).build())
        }
    }

    override suspend fun offerings(): List<SubscriptionOffering> {
        if (!isConfigured) throw SubscriptionOperationError.NotConfigured
        val current = try {
            Purchases.sharedInstance.awaitOfferings().current
        } catch (error: Exception) {
            throw SubscriptionOperationError.LoadFailed
        } ?: return emptyList()
        return listOf(
            SubscriptionOffering(
                id = current.identifier,
                title = current.serverDescription,
                packages = current.availablePackages.map(::mapPackage),
            )
        )
    }

    override suspend fun purchase(product: SubscriptionPackage): SubscriptionStatus {
        if (!isConfigured) throw SubscriptionOperationError.NotConfigured
        val activity = activityProvider() ?: throw SubscriptionOperationError.PurchaseFailed
        val rcPackage = findPackage(product) ?: throw SubscriptionOperationError.LoadFailed
        return try {
            val result = Purchases.sharedInstance.awaitPurchase(
                PurchaseParams.Builder(activity, rcPackage).build()
            )
            mapStatus(result.customerInfo)
        } catch (error: PurchasesException) {
            if (error.code == PurchasesErrorCode.PurchaseCancelledError) {
                throw SubscriptionOperationError.Cancelled
            }
            throw SubscriptionOperationError.PurchaseFailed
        } catch (error: Exception) {
            throw SubscriptionOperationError.PurchaseFailed
        }
    }

    override suspend fun restore(): SubscriptionStatus {
        if (!isConfigured) throw SubscriptionOperationError.NotConfigured
        return try {
            mapStatus(Purchases.sharedInstance.awaitRestore())
        } catch (error: Exception) {
            throw SubscriptionOperationError.RestoreFailed
        }
    }

    override suspend fun refresh(): SubscriptionStatus? {
        if (!isConfigured) return null
        // CACHED_OR_FETCHED returns the cached data when offline, so a paying
        // user keeps their status; only a true unknown (no cache, no network)
        // is null.
        return try {
            mapStatus(
                Purchases.sharedInstance.awaitCustomerInfo(CacheFetchPolicy.CACHED_OR_FETCHED)
            )
        } catch (error: Exception) {
            null
        }
    }

    /**
     * The provider package behind a domain package.
     *
     * The domain id is the Play product id, so the lookup is by product id:
     * a package that is no longer offered is simply not found, and the
     * purchase reports a load failure instead of buying something else.
     */
    private suspend fun findPackage(target: SubscriptionPackage): Package? = try {
        Purchases.sharedInstance.awaitOfferings().current?.availablePackages
            ?.firstOrNull { mapPackage(it).id == target.id }
    } catch (error: Exception) {
        null
    }

    private fun mapPackage(rcPackage: Package): SubscriptionPackage {
        val product = rcPackage.product
        return SubscriptionPackage(
            // The id of the purchasable unit: a Google subscription is
            // "<subscriptionId>:<basePlanId>", a one-time product its
            // productId. `StoreProduct.id` is empty for one-time products, so
            // the Play product id is the fallback, and the package
            // identifier is the last resort - two packages must never share
            // an id, or the paywall could buy the wrong one.
            id = product.id.ifEmpty {
                product.googleProduct?.productId.orEmpty().ifEmpty { rcPackage.identifier }
            },
            title = product.title,
            priceString = product.price.formatted,
        )
    }

    private fun mapStatus(info: CustomerInfo): SubscriptionStatus {
        val entitlement = info.entitlements.active[entitlementId]
        return SubscriptionStatus(
            activeEntitlements = if (entitlement?.isActive == true) setOf(Entitlement.PRO) else emptySet(),
            expirationDate = entitlement?.expirationDate?.time,
            willRenew = entitlement?.willRenew ?: false,
            productIdentifier = entitlement?.productIdentifier,
        )
    }

    companion object {
        /**
         * The entitlement identifier in the RevenueCat dashboard.
         *
         * Mirrors iOS `Config.proEntitlementID` - the dashboard calls it
         * `premium` while the domain type is `Entitlement.PRO`; only this
         * mapping knows the provider's spelling.
         */
        const val PREMIUM_ENTITLEMENT_ID = "premium"
    }
}
