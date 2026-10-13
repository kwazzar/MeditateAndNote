//
//  PaywallViewModel.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore
import Observation

@MainActor
@Observable
final class PaywallViewModel {
    private let providable: any SubscriptionProvidable
    private let manageable: any SubscriptionManageable

    private(set) var packages: [SubscriptionPackage] = []
    private(set) var isPremium: Bool
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var selectedPackage: SubscriptionPackage?

    init(providable: any SubscriptionProvidable, manageable: any SubscriptionManageable) {
        self.providable = providable
        self.manageable = manageable
        self.isPremium = providable.isActive(.pro)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let flat = try await manageable.offerings().flatMap(\.packages)
            packages = flat
            if selectedPackage == nil { selectedPackage = flat.first }
        } catch SubscriptionOperationError.notConfigured {
            errorMessage = "Subscriptions are unavailable right now."
        } catch {
            errorMessage = "Couldn't load plans. Please try again."
        }
    }

    func purchaseSelected() async {
        guard let selectedPackage else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            try await manageable.purchase(selectedPackage)
            isPremium = providable.isActive(.pro)
        } catch SubscriptionOperationError.cancelled {
            // user cancelled — silent
        } catch {
            errorMessage = "Purchase failed. Please try again."
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            try await manageable.restore()
            isPremium = providable.isActive(.pro)
        } catch SubscriptionOperationError.cancelled {
            // user cancelled — silent
        } catch {
            errorMessage = "Restore failed. Please try again."
        }
    }
}