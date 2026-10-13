import XCTest
import MeditateAndNoteCore

final class SubscriptionStatusTests: XCTestCase {
    func test_isActive_trueOnlyForPresentEntitlement() {
        let status = SubscriptionStatus(
            activeEntitlements: [.pro], expirationDate: nil, willRenew: true, productIdentifier: "p"
        )
        XCTAssertTrue(status.isActive(.pro))
    }

    func test_isActive_falseWhenAbsent() {
        XCTAssertFalse(SubscriptionStatus.none.isActive(.pro))
    }

    func test_none_isInactive() {
        XCTAssertEqual(SubscriptionStatus.none.activeEntitlements, [])
        XCTAssertFalse(SubscriptionStatus.none.willRenew)
    }
}
