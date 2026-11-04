package com.mn.android.application.subscription

import com.mn.android.domain.subscription.Entitlement
import com.mn.android.domain.subscription.SubscriptionCache
import com.mn.android.domain.subscription.SubscriptionManaging
import com.mn.android.domain.subscription.SubscriptionOffering
import com.mn.android.domain.subscription.SubscriptionOperationError
import com.mn.android.domain.subscription.SubscriptionPackage
import com.mn.android.domain.subscription.SubscriptionStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlinx.coroutines.runBlocking

/**
 * The subscription state owner.
 *
 * The trust model is the point of these tests: the provider is the only
 * authority that may grant an entitlement, the cache is a fast path, and a
 * missing provider grants nothing at all.
 */
class SubscriptionManagerTest {

    @Test
    fun cachedStatus_isExposedBeforeTheFirstRefresh() = runBlocking {
        val cache = FakeCache(proStatus())
        val manager = SubscriptionManager(FakeService(), cache)

        assertTrue(manager.isPro)
        assertEquals(0, cache.saves)
    }

    @Test
    fun refresh_grantsPro() = runBlocking {
        val service = FakeService(refreshResult = proStatus())
        val manager = SubscriptionManager(service, FakeCache())

        manager.refresh()

        assertTrue(manager.isPro)
    }

    @Test
    fun refresh_withoutChange_doesNotWriteTheCacheAgain() = runBlocking {
        val cache = FakeCache(proStatus())
        val service = FakeService(refreshResult = proStatus())
        val manager = SubscriptionManager(service, cache)

        manager.refresh()

        // The status did not change, so nothing was published and nothing was
        // written - the same rule the iOS manager follows.
        assertEquals(0, cache.saves)
    }

    @Test
    fun purchase_grantsPro() = runBlocking {
        val cache = FakeCache()
        val service = FakeService(purchaseResult = proStatus())
        val manager = SubscriptionManager(service, cache)

        manager.purchase(lifetimePackage())

        assertTrue(manager.isPro)
        assertEquals(1, cache.saves)
    }

    @Test
    fun purchase_cancelled_leavesTheStatusUnchanged() = runBlocking {
        val cache = FakeCache()
        val service = FakeService(purchaseError = SubscriptionOperationError.Cancelled)
        val manager = SubscriptionManager(service, cache)

        val failure = runCatching { manager.purchase(lifetimePackage()) }.exceptionOrNull()

        assertTrue(failure is SubscriptionOperationError)
        assertFalse(manager.isPro)
        assertEquals(0, cache.saves)
    }

    @Test
    fun restore_withoutPurchases_isFree() = runBlocking {
        val manager = SubscriptionManager(FakeService(purchaseResult = SubscriptionStatus.NONE), FakeCache())

        val restored = manager.restore()

        assertFalse(restored.isActive(Entitlement.PRO))
        assertFalse(manager.isPro)
    }

    @Test
    fun forgedCache_cannotGrantPro() = runBlocking {
        // The cache claims pro, the provider says no: the provider wins.
        val cache = FakeCache(proStatus())
        val service = FakeService(refreshResult = SubscriptionStatus.NONE)
        val manager = SubscriptionManager(service, cache)

        manager.refresh()

        assertFalse(manager.isPro)
    }

    @Test
    fun unconfiguredProvider_neverGrantsPro() = runBlocking {
        val cache = FakeCache(proStatus())
        val manager = SubscriptionManager(FakeService(isConfigured = false), cache)

        assertFalse(manager.isPro)
        assertFalse(manager.isConfigured)
    }

    @Test
    fun refresh_thatCannotReport_keepsTheLastKnownStatus() = runBlocking {
        val service = FakeService(refreshResult = null)
        val manager = SubscriptionManager(service, FakeCache(proStatus()))

        val status = manager.refresh()

        assertTrue(status!!.isActive(Entitlement.PRO))
        assertTrue(manager.isPro)
    }

    @Test
    fun debugBypass_grantsPro_withoutPurchase() = runBlocking {
        val cache = FakeCache(SubscriptionStatus.NONE)
        val manager = SubscriptionManager(FakeService(), cache)

        assertFalse(manager.isPro)

        manager.setDebugBypassPro(true)
        assertTrue(manager.isPro)
        assertTrue(manager.status.value.isActive(Entitlement.PRO))
        // The forged entitlement never reaches the cache.
        assertEquals(SubscriptionStatus.NONE, cache.load())

        manager.setDebugBypassPro(false)
        assertFalse(manager.isPro)
    }

    private fun proStatus() = SubscriptionStatus(
        activeEntitlements = setOf(Entitlement.PRO),
        productIdentifier = "lifetime",
    )

    private fun lifetimePackage() = SubscriptionPackage(
        id = "lifetime",
        title = "Premium Lifetime",
        priceString = "8.99 US$",
    )

    private class FakeService(
        override val isConfigured: Boolean = true,
        private val offerings: List<SubscriptionOffering> = emptyList(),
        private val refreshResult: SubscriptionStatus? = null,
        private val purchaseResult: SubscriptionStatus = SubscriptionStatus.NONE,
        private val purchaseError: SubscriptionOperationError? = null,
    ) : SubscriptionManaging {
        override suspend fun offerings(): List<SubscriptionOffering> = offerings
        override suspend fun purchase(product: SubscriptionPackage): SubscriptionStatus {
            purchaseError?.let { throw it }
            return purchaseResult
        }
        override suspend fun restore(): SubscriptionStatus = purchaseResult
        override suspend fun refresh(): SubscriptionStatus? = refreshResult
    }

    private class FakeCache(private var stored: SubscriptionStatus? = null) : SubscriptionCache {
        var saves = 0
        override fun load(): SubscriptionStatus? = stored
        override fun save(status: SubscriptionStatus) {
            stored = status
            saves++
        }
    }
}
