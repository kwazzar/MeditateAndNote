import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    private func pro() -> SubscriptionStatus {
        .init(activeEntitlements: [.pro], expirationDate: nil, willRenew: true, productIdentifier: "p")
    }

    func test_cacheFirstThenRefreshGrants() async {
        let service = MockSubscriptionService()
        service.nextStatus = pro()
        let cache = MemorySubscriptionCache(pro())
        let bus = DomainEventBus()
        let manager = SubscriptionManager(service: service, cache: cache, eventBus: bus)

        XCTAssertTrue(manager.isPremium) // cache-first

        let changed = await manager.refresh()
        XCTAssertTrue(changed.isActive(.pro))
        XCTAssertEqual(cache.load(), pro()) // cache overwritten by RC result
    }

    func test_refreshDowngradePublishesEvent() async {
        let service = MockSubscriptionService()
        service.nextStatus = .none
        let cache = MemorySubscriptionCache(pro())
        let bus = DomainEventBus()
        let recorder = EventRecorder()
        let token = bus.subscribe { recorder.record($0) }
        let manager = SubscriptionManager(service: service, cache: cache, eventBus: bus)

        _ = await manager.refresh()
        bus.unsubscribe(token)

        XCTAssertFalse(manager.isPremium)
        XCTAssertEqual(recorder.count { if case .subscriptionChanged = $0 { true } else { false } }, 1)
    }

    func test_cancelledPurchaseLeavesStatusUnchanged() async {
        let service = MockSubscriptionService()
        service.purchaseResult = .failure(SubscriptionOperationError.cancelled)
        let manager = SubscriptionManager(service: service, cache: MemorySubscriptionCache(.none), eventBus: DomainEventBus())

        do {
            _ = try await manager.purchase(SubscriptionPackage(id: "p", title: "t", priceString: "$1"))
            XCTFail("purchase should throw")
        } catch let error as SubscriptionOperationError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        XCTAssertFalse(manager.isPremium)
    }
}