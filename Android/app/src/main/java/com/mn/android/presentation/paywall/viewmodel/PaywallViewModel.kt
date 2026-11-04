package com.mn.android.presentation.paywall.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mn.android.domain.subscription.Entitlement
import com.mn.android.domain.subscription.SubscriptionManageable
import com.mn.android.domain.subscription.SubscriptionOffering
import com.mn.android.domain.subscription.SubscriptionOperationError
import com.mn.android.domain.subscription.SubscriptionPackage
import com.mn.android.domain.subscription.SubscriptionProvidable
import com.mn.android.domain.subscription.SubscriptionStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * What went wrong on the paywall. The screen turns it into a message, so no
 * user-visible string is built here.
 */
enum class PaywallError {
    /** No billing provider - the app has no RevenueCat key. */
    UNAVAILABLE,

    /** The plans could not be read. */
    LOAD_FAILED,

    /** The purchase did not go through. */
    PURCHASE_FAILED,

    /** The restore did not go through. */
    RESTORE_FAILED,
}

/**
 * The Android counterpart of iOS `PaywallViewModel`
 * (`MeditateAndNote/ViewModels/PaywallViewModel.swift`).
 *
 * It holds what the paywall draws - the packages, the selected one, the
 * loading flag, the last error - and it survives a recomposition, so the
 * packages are not re-fetched on every redraw.
 *
 * The purchase rules live in the provider; this only orchestrates. The three
 * lambdas are the seam the tests replace.
 */
class PaywallViewModel(
    providable: SubscriptionProvidable,
    manageable: SubscriptionManageable,
    private val loadOfferings: suspend () -> List<SubscriptionOffering> = { manageable.offerings() },
    private val purchasePackage: suspend (SubscriptionPackage) -> SubscriptionStatus = { manageable.purchase(it) },
    private val restorePurchases: suspend () -> SubscriptionStatus = { manageable.restore() },
) : ViewModel() {

    data class UiState(
        val packages: List<SubscriptionPackage> = emptyList(),
        /** Id of the package the Subscribe button buys. */
        val selectedPackageId: String? = null,
        val isLoading: Boolean = false,
        val error: PaywallError? = null,
    ) {
        val selectedPackage: SubscriptionPackage?
            get() = packages.firstOrNull { it.id == selectedPackageId }
    }

    private val _state = MutableStateFlow(UiState())

    val state: StateFlow<UiState> = _state.asStateFlow()

    /**
     * The pro entitlement, straight from the manager. The paywall closes
     * itself the moment this turns true - a purchase that succeeded must not
     * leave the user on the offer screen.
     */
    val isPremium: StateFlow<Boolean> = providable.status
        .map { it.isActive(Entitlement.PRO) }
        .stateIn(viewModelScope, SharingStarted.Eagerly, providable.isActive(Entitlement.PRO))

    /** Reads the packages on offer. */
    fun load() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val packages = loadOfferings().flatMap { it.packages }
                _state.update {
                    it.copy(
                        packages = packages,
                        selectedPackageId = it.selectedPackageId ?: packages.firstOrNull()?.id,
                        isLoading = false,
                    )
                }
            } catch (error: SubscriptionOperationError) {
                _state.update {
                    it.copy(
                        isLoading = false,
                        error = if (error == SubscriptionOperationError.NotConfigured) {
                            PaywallError.UNAVAILABLE
                        } else {
                            PaywallError.LOAD_FAILED
                        },
                    )
                }
            } catch (error: Exception) {
                _state.update { it.copy(isLoading = false, error = PaywallError.LOAD_FAILED) }
            }
        }
    }

    /** Selects the package the Subscribe button buys. */
    fun select(product: SubscriptionPackage) {
        _state.update { it.copy(selectedPackageId = product.id) }
    }

    /** Buys the selected package. A cancelled purchase is not an error. */
    fun purchaseSelected() {
        val target = _state.value.selectedPackage ?: return
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                purchasePackage(target)
                _state.update { it.copy(isLoading = false) }
            } catch (error: SubscriptionOperationError) {
                if (error == SubscriptionOperationError.Cancelled) {
                    _state.update { it.copy(isLoading = false) }
                } else {
                    _state.update { it.copy(isLoading = false, error = PaywallError.PURCHASE_FAILED) }
                }
            } catch (error: Exception) {
                _state.update { it.copy(isLoading = false, error = PaywallError.PURCHASE_FAILED) }
            }
        }
    }

    /** Restores the purchases of the current Play Store account. */
    fun restore() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                restorePurchases()
                _state.update { it.copy(isLoading = false) }
            } catch (error: SubscriptionOperationError) {
                if (error == SubscriptionOperationError.Cancelled) {
                    _state.update { it.copy(isLoading = false) }
                } else {
                    _state.update { it.copy(isLoading = false, error = PaywallError.RESTORE_FAILED) }
                }
            } catch (error: Exception) {
                _state.update { it.copy(isLoading = false, error = PaywallError.RESTORE_FAILED) }
            }
        }
    }
}
