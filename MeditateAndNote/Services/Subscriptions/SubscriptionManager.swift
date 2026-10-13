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
@Observable
@MainActor
final class SubscriptionManager: SubscriptionProvidable, SubscriptionManageable {
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

    var isConfigured: Bool { service.isConfigured }

    func offerings() async throws -> [SubscriptionOffering] {
        guard service.isConfigured else { throw SubscriptionOperationError.notConfigured }
        return try await service.offerings()
    }

    @discardableResult
    func refresh() async -> SubscriptionStatus? {
        // `nil` = provider could not report (offline, no cache): keep last-known
        // status rather than optimistically downgrading a paying user.
        if let fresh = await service.refresh() {
            apply(fresh)
        }
        return status
    }

    @discardableResult
    func purchase(_ package: SubscriptionPackage) async throws -> SubscriptionStatus {
        guard service.isConfigured else { throw SubscriptionOperationError.notConfigured }
        let purchased = try await service.purchase(package)
        apply(purchased)
        return purchased
    }

    @discardableResult
    func restore() async throws -> SubscriptionStatus {
        guard service.isConfigured else { throw SubscriptionOperationError.notConfigured }
        let restored = try await service.restore()
        apply(restored)
        return restored
    }

    private func apply(_ newStatus: SubscriptionStatus) {
        guard newStatus != status else { return }
        status = newStatus
        cache.save(newStatus)
        eventBus.publish(.subscriptionChanged(newStatus))
    }
}