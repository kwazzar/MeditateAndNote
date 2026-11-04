package com.mn.android.application.subscription

import com.mn.android.domain.subscription.Entitlement
import com.mn.android.domain.subscription.SubscriptionCache
import com.mn.android.domain.subscription.SubscriptionManageable
import com.mn.android.domain.subscription.SubscriptionManaging
import com.mn.android.domain.subscription.SubscriptionOffering
import com.mn.android.domain.subscription.SubscriptionPackage
import com.mn.android.domain.subscription.SubscriptionProvidable
import com.mn.android.domain.subscription.SubscriptionStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Application-layer owner of the current [SubscriptionStatus].
 *
 * The Android counterpart of iOS `SubscriptionManager`
 * (`MeditateAndNote/Services/Subscriptions/SubscriptionManager.swift`).
 *
 * Trust model: the provider (the [SubscriptionManaging] service) is the sole
 * authority. The cache is a UX fast-path only - it seeds the initial value,
 * then every refresh / purchase / restore result from the provider overwrites
 * it. An unconfigured provider never grants an entitlement, even if the cache
 * claims one.
 */
class SubscriptionManager(
    private val service: SubscriptionManaging,
    private val cache: SubscriptionCache,
) : SubscriptionProvidable, SubscriptionManageable {

    private var providerStatus: SubscriptionStatus = initialStatus()

    private val _status = MutableStateFlow(providerStatus)

    /** The last known status. Emits only when it actually changes. */
    override val status: StateFlow<SubscriptionStatus> = _status.asStateFlow()

    private val _debugBypassPro = MutableStateFlow(false)

    /**
     * Debug-only switch: the app behaves as if `pro` were active, without a
     * purchase. The provider stays the authority - only the published status
     * is patched, and the cache never holds the forged entitlement.
     */
    val debugBypassPro: StateFlow<Boolean> = _debugBypassPro.asStateFlow()

    /** True when the `pro` entitlement is active. */
    val isPro: Boolean
        get() = isActive(Entitlement.PRO)

    override fun isActive(entitlement: Entitlement): Boolean = _status.value.isActive(entitlement)

    /** False when no provider key is configured. */
    val isConfigured: Boolean
        get() = service.isConfigured

    private fun initialStatus(): SubscriptionStatus =
        if (service.isConfigured) cache.load() ?: SubscriptionStatus.NONE else SubscriptionStatus.NONE

    override suspend fun offerings(): List<SubscriptionOffering> = service.offerings()

    override suspend fun purchase(product: SubscriptionPackage): SubscriptionStatus {
        val purchased = service.purchase(product)
        apply(purchased)
        return purchased
    }

    override suspend fun restore(): SubscriptionStatus {
        val restored = service.restore()
        apply(restored)
        return restored
    }

    /**
     * The provider's current status.
     *
     * `null` = the provider could not report (offline, no cache): the
     * last-known status is kept rather than optimistically downgrading a
     * paying user.
     */
    override suspend fun refresh(): SubscriptionStatus? {
        val fresh = service.refresh() ?: return _status.value
        apply(fresh)
        return fresh
    }

    /** Debug-only: treat the user as pro without a purchase. */
    fun setDebugBypassPro(enabled: Boolean) {
        if (enabled == _debugBypassPro.value) return
        _debugBypassPro.value = enabled
        publish()
    }

    private fun apply(newStatus: SubscriptionStatus) {
        if (newStatus == providerStatus) return
        providerStatus = newStatus
        cache.save(newStatus)
        publish()
    }

    /**
     * Publishes the status the app sees: the provider's, plus `pro` while the
     * debug bypass is on. The cache only ever holds the provider's status.
     */
    private fun publish() {
        val next = if (_debugBypassPro.value) {
            providerStatus.copy(activeEntitlements = providerStatus.activeEntitlements + Entitlement.PRO)
        } else {
            providerStatus
        }
        _status.value = next
    }
}
