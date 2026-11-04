package com.mn.android.application.subscription

import com.mn.android.data.SandboxSubscriptionService
import com.mn.android.domain.subscription.Entitlement
import com.mn.android.domain.subscription.SubscriptionCache
import com.mn.android.domain.subscription.SubscriptionStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlinx.coroutines.runBlocking

/**
 * The local stand-in that lets a debug build without a RevenueCat key test
 * the paywall and the Pro gates for free.
 */
class SandboxSubscriptionServiceTest {

    @Test
    fun itOffersOnePackage() = runBlocking {
        val offerings = SandboxSubscriptionService().offerings()

        assertEquals(1, offerings.size)
        assertEquals(1, offerings.first().packages.size)
        assertTrue(offerings.first().packages.first().priceString.isNotEmpty())
    }

    @Test
    fun buyingGrantsPro() = runBlocking {
        val service = SandboxSubscriptionService()
        val product = service.offerings().first().packages.first()

        val status = service.purchase(product)

        assertTrue(status.isActive(Entitlement.PRO))
    }

    @Test
    fun restoringGrantsPro() = runBlocking {
        val status = SandboxSubscriptionService().restore()

        assertTrue(status.isActive(Entitlement.PRO))
    }

    @Test
    fun theStatusSurvivesARestartThroughTheCache() = runBlocking {
        val cache = FakeCache()
        val manager = SubscriptionManager(SandboxSubscriptionService(), cache)
        val product = manager.offerings().first().packages.first()

        manager.purchase(product)

        // A new manager over the same cache is what a relaunch looks like.
        val relaunched = SubscriptionManager(SandboxSubscriptionService(), cache)
        assertTrue(relaunched.isPro)
    }

    @Test
    fun nothingIsGrantedBeforeTheFirstPurchase() = runBlocking {
        val manager = SubscriptionManager(SandboxSubscriptionService(), FakeCache())

        assertFalse(manager.isPro)
        assertEquals(SubscriptionStatus.NONE, manager.status.value)
    }

    private class FakeCache : SubscriptionCache {
        private var stored: SubscriptionStatus? = null
        override fun load(): SubscriptionStatus? = stored
        override fun save(status: SubscriptionStatus) {
            stored = status
        }
    }
}
