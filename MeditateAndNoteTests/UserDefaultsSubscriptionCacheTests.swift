import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

final class UserDefaultsSubscriptionCacheTests: XCTestCase {
    private func makeCache() -> (UserDefaultsSubscriptionCache, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        return (UserDefaultsSubscriptionCache(defaults: defaults), defaults)
    }

    func test_roundTrip() {
        let (cache, _) = makeCache()
        let status = SubscriptionStatus(activeEntitlements: [.pro], expirationDate: nil, willRenew: true, productIdentifier: "p")
        cache.save(status)
        XCTAssertEqual(cache.load(), status)
    }

    func test_emptyReturnsNil() {
        let (cache, _) = makeCache()
        XCTAssertNil(cache.load())
    }

    func test_corruptedBlobReturnsNilNotCrash() {
        let (cache, defaults) = makeCache()
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: "subscription.status.v1")
        XCTAssertNil(cache.load())
    }
}