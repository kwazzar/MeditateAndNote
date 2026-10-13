//
//  SubscriptionViewModel.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore
import Observation

@MainActor
@Observable
final class SubscriptionViewModel {
    private let providable: any SubscriptionProvidable
    private let manageable: any SubscriptionManageable

    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var priceText: String?

    var isPremium: Bool { providable.isActive(.pro) }

    init(providable: any SubscriptionProvidable, manageable: any SubscriptionManageable) {
        self.providable = providable
        self.manageable = manageable
        Task { await loadPrice() }
    }

    func restore() async {
        isBusy = true
        errorMessage = nil
        do {
            try await manageable.restore()
        } catch SubscriptionOperationError.cancelled {
            // user cancelled — no error surfaced
        } catch let error as SubscriptionOperationError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = Self.message(for: .restoreFailed)
        }
        isBusy = false
    }

    func refreshStatus() async {
        _ = await manageable.refresh()
    }

    private func loadPrice() async {
        guard let offerings = try? await manageable.offerings(),
              let price = offerings.first?.packages.first?.priceString else { return }
        priceText = price
    }

    private static func message(for error: SubscriptionOperationError) -> String {
        switch error {
        case .notConfigured, .loadFailed:
            return "Subscriptions are unavailable right now."
        case .purchaseFailed, .restoreFailed:
            return "Something went wrong. Please try again."
        case .cancelled:
            return ""
        }
    }
}