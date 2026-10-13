import Foundation
import MeditateAndNoteCore

/// Shared subscription test doubles used by SubscriptionManagerTests,
/// SubscriptionTrustBoundaryTests, SubscriptionViewModelTests, PaywallViewModelTests.
@MainActor
final class MockSubscriptionService: SubscriptionManaging {
    var isConfigured = true
    var nextStatus: SubscriptionStatus = .none
    var offeringsToReturn: [SubscriptionOffering] = []
    var purchaseResult: Result<SubscriptionStatus, Error> = .success(.none)
    var restoreError: Error?
    /// When true, `refresh()` reports "could not determine" (nil) — simulates offline.
    var refreshFails = false

    func offerings() async throws -> [SubscriptionOffering] { offeringsToReturn }

    func purchase(_ package: SubscriptionPackage) async throws -> SubscriptionStatus {
        switch purchaseResult {
        case .success(let status): return status
        case .failure(let error): throw error
        }
    }

    func restore() async throws -> SubscriptionStatus {
        if let restoreError { throw restoreError }
        return nextStatus
    }

    func refresh() async -> SubscriptionStatus? { refreshFails ? nil : nextStatus }
}

struct MemorySubscriptionCache: SubscriptionCache {
    final class Box: @unchecked Sendable {
        var value: SubscriptionStatus?
        init(_ value: SubscriptionStatus?) { self.value = value }
    }

    private let box: Box

    init(_ value: SubscriptionStatus?) { box = Box(value) }

    func load() -> SubscriptionStatus? { box.value }
    func save(_ status: SubscriptionStatus) { box.value = status }
}

final class EventRecorder: @unchecked Sendable {
    private var events: [DomainEvent] = []
    private let lock = NSLock()

    func record(_ event: DomainEvent) {
        lock.lock(); defer { lock.unlock() }
        events.append(event)
    }

    func count(where predicate: (DomainEvent) -> Bool) -> Int {
        lock.lock(); defer { lock.unlock() }
        return events.filter(predicate).count
    }
}