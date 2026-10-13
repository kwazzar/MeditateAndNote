//
//  SubscriptionManager.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore
import Observation

/// Application-layer owner of the current `SubscriptionStatus`.
///
/// Trust model: RevenueCat (the `SubscriptionManaging` service) is the sole
/// authority. The cache is a UX fast-path only — it is used for the initial
/// value, then every `refresh()` / purchase / restore result from the service
/// overwrites it. An unconfigured service never grants an entitlement, even if
/// the cache claims one.
@MainActor
@Observable
final class SubscriptionManager: EntitlementProviding {
    private let service: any SubscriptionManaging
    private let cache: any SubscriptionCache
    private let eventBus: any DomainEventPublisher

    private(set) var status: SubscriptionStatus

    var isPremium: Bool { isActive(.pro) }

    init(service: any SubscriptionManaging, cache: any SubscriptionCache, eventBus: any DomainEventPublisher) {
        self.service = service
        self.cache = cache
        self.eventBus = eventBus
        self.status = service.isConfigured ? (cache.load() ?? .none) : .none
    }

    func isActive(_ entitlement: Entitlement) -> Bool {
        status.isActive(entitlement)
    }

    @discardableResult
    func refresh() async -> SubscriptionStatus {
        let fresh = await service.refresh()
        apply(fresh)
        return status
    }

    func purchase(_ package: SubscriptionPackage) async throws {
        let purchased = try await service.purchase(package)
        apply(purchased)
    }

    func restore() async throws {
        let restored = try await service.restore()
        apply(restored)
    }

    private func apply(_ newStatus: SubscriptionStatus) {
        guard newStatus != status else { return }
        status = newStatus
        cache.save(newStatus)
        eventBus.publish(.subscriptionChanged(newStatus))
    }
}