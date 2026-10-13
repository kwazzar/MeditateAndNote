import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

@MainActor
final class SubscriptionTrustBoundaryTests: XCTestCase {
    private func pro() -> SubscriptionStatus {
        .init(activeEntitlements: [.pro], expirationDate: nil, willRenew: true, productIdentifier: "p")
    }

    func test_unconfiguredServiceNeverGrantsEvenWithCachedPro() async {
        let service = MockSubscriptionService()
        service.isConfigured = false
        service.nextStatus = .none

        let manager = SubscriptionManager(service: service, cache: MemorySubscriptionCache(pro()), eventBus: DomainEventBus())

        XCTAssertFalse(manager.isPremium) // cache must not grant when RC is unconfigured
        _ = await manager.refresh()
        XCTAssertFalse(manager.isPremium)
    }

    func test_refreshResultWinsOverCache() async {
        // RC reports inactive even though the cache says active → free after refresh.
        let service = MockSubscriptionService()
        service.nextStatus = .none

        let manager = SubscriptionManager(service: service, cache: MemorySubscriptionCache(pro()), eventBus: DomainEventBus())

        _ = await manager.refresh()
        XCTAssertFalse(manager.isPremium)
    }

    func test_refreshFailureKeepsLastKnownPremium() async {
        // A paying user goes offline: the provider can't report (nil), so the
        // manager must keep the last-known status, never downgrade to free.
        let service = MockSubscriptionService()
        service.nextStatus = pro()

        let manager = SubscriptionManager(service: service, cache: MemorySubscriptionCache(.none), eventBus: DomainEventBus())

        _ = await manager.refresh() // provider reports pro
        XCTAssertTrue(manager.isPremium)

        service.refreshFails = true // offline / cannot determine
        _ = await manager.refresh()
        XCTAssertTrue(manager.isPremium, "offline refresh must not drop premium")
    }

    func test_purchaseWhenUnconfiguredThrowsNotConfigured() async {
        let service = MockSubscriptionService()
        service.isConfigured = false
        let manager = SubscriptionManager(service: service, cache: MemorySubscriptionCache(.none), eventBus: DomainEventBus())

        do {
            _ = try await manager.purchase(SubscriptionPackage(id: "p", title: "t", priceString: "$1"))
            XCTFail("purchase should throw when unconfigured")
        } catch let error as SubscriptionOperationError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}