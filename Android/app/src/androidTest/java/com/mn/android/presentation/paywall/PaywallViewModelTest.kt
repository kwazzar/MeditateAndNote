package com.mn.android.presentation.paywall

import com.mn.android.application.subscription.SubscriptionManager
import com.mn.android.domain.subscription.Entitlement
import com.mn.android.domain.subscription.SubscriptionCache
import com.mn.android.domain.subscription.SubscriptionManaging
import com.mn.android.domain.subscription.SubscriptionOffering
import com.mn.android.domain.subscription.SubscriptionOperationError
import com.mn.android.domain.subscription.SubscriptionPackage
import com.mn.android.domain.subscription.SubscriptionStatus
import com.mn.android.presentation.paywall.viewmodel.PaywallError
import com.mn.android.presentation.paywall.viewmodel.PaywallViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * The paywall state holder: the packages, the selection, and the mapping of
 * a failed operation onto a message the screen can show.
 */
class PaywallViewModelTest {

    @Before
    fun setup() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun load_showsThePackagesAndSelectsTheFirst() {
        val vm = viewModel(service = FakeService(offerings = listOf(offering())))

        vm.load()

        assertEquals(listOf(PACKAGE), vm.state.value.packages)
        assertEquals(PACKAGE.id, vm.state.value.selectedPackageId)
        assertNull(vm.state.value.error)
    }

    @Test
    fun load_withoutAProvider_reportsUnavailable() {
        val vm = viewModel(service = FakeService(isConfigured = false))

        vm.load()

        assertEquals(PaywallError.UNAVAILABLE, vm.state.value.error)
        assertTrue(vm.state.value.packages.isEmpty())
    }

    @Test
    fun load_thatFails_reportsLoadFailed() {
        val vm = viewModel(service = FakeService(loadError = SubscriptionOperationError.LoadFailed))

        vm.load()

        assertEquals(PaywallError.LOAD_FAILED, vm.state.value.error)
    }

    @Test
    fun purchase_grantsPro() {
        val vm = viewModel(
            service = FakeService(offerings = listOf(offering()), purchaseResult = proStatus())
        )

        vm.load()
        vm.purchaseSelected()

        assertTrue(vm.isPremium.value)
        assertNull(vm.state.value.error)
    }

    @Test
    fun purchase_cancelled_showsNoError() {
        val vm = viewModel(
            service = FakeService(
                offerings = listOf(offering()),
                purchaseError = SubscriptionOperationError.Cancelled,
            )
        )

        vm.load()
        vm.purchaseSelected()

        assertNull(vm.state.value.error)
        assertTrue(!vm.isPremium.value)
    }

    @Test
    fun purchase_thatFails_reportsPurchaseFailed() {
        val vm = viewModel(
            service = FakeService(
                offerings = listOf(offering()),
                purchaseError = SubscriptionOperationError.PurchaseFailed,
            )
        )

        vm.load()
        vm.purchaseSelected()

        assertEquals(PaywallError.PURCHASE_FAILED, vm.state.value.error)
    }

    @Test
    fun restore_thatFails_reportsRestoreFailed() {
        val vm = viewModel(service = FakeService(restoreError = SubscriptionOperationError.RestoreFailed))

        vm.restore()

        assertEquals(PaywallError.RESTORE_FAILED, vm.state.value.error)
    }

    @Test
    fun select_picksAnotherPackage() {
        val second = PACKAGE.copy(id = "monthly", title = "Monthly", priceString = "1.99 US$")
        val vm = viewModel(service = FakeService(offerings = listOf(offering(), offering(second))))

        vm.load()
        vm.select(second)

        assertEquals(second.id, vm.state.value.selectedPackageId)
    }

    private fun viewModel(service: FakeService): PaywallViewModel {
        val manager = SubscriptionManager(service, FakeCache())
        return PaywallViewModel(providable = manager, manageable = manager)
    }

    private fun offering(product: SubscriptionPackage = PACKAGE) = SubscriptionOffering(
        id = "default",
        title = "Default",
        packages = listOf(product),
    )

    private fun proStatus() = SubscriptionStatus(
        activeEntitlements = setOf(Entitlement.PRO),
        productIdentifier = "lifetime",
    )

    private class FakeService(
        override val isConfigured: Boolean = true,
        private val offerings: List<SubscriptionOffering> = emptyList(),
        private val loadError: SubscriptionOperationError? = null,
        private val purchaseResult: SubscriptionStatus = SubscriptionStatus.NONE,
        private val purchaseError: SubscriptionOperationError? = null,
        private val restoreError: SubscriptionOperationError? = null,
    ) : SubscriptionManaging {
        override suspend fun offerings(): List<SubscriptionOffering> {
            // The real service refuses to talk to a provider that was never
            // configured - the fake does the same.
            if (!isConfigured) throw SubscriptionOperationError.NotConfigured
            loadError?.let { throw it }
            return offerings
        }
        override suspend fun purchase(product: SubscriptionPackage): SubscriptionStatus {
            purchaseError?.let { throw it }
            return purchaseResult
        }
        override suspend fun restore(): SubscriptionStatus {
            restoreError?.let { throw it }
            return SubscriptionStatus.NONE
        }
        override suspend fun refresh(): SubscriptionStatus? = null
    }

    private class FakeCache : SubscriptionCache {
        override fun load(): SubscriptionStatus? = null
        override fun save(status: SubscriptionStatus) = Unit
    }

    private companion object {
        val PACKAGE = SubscriptionPackage(
            id = "lifetime",
            title = "Premium Lifetime",
            priceString = "8.99 US$",
        )
    }
}
