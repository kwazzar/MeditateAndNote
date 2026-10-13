//
//  SubscriptionScope.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore

/// Owns the `SubscriptionManager` and its production dependencies
/// (RevenueCat service + UserDefaults cache).
@MainActor
final class SubscriptionScope {
    let manager: SubscriptionManager

    init(eventBus: any DomainEventPublisher) {
        let service = RevenueCatPurchasesService.configure(
            apiKey: Config.revenueCatAPIKey,
            proEntitlementID: Config.proEntitlementID
        )
        let cache = UserDefaultsSubscriptionCache()
        manager = SubscriptionManager(service: service, cache: cache, eventBus: eventBus)
    }
}