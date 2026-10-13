import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

@MainActor
final class PaywallViewModelTests: XCTestCase {
    func test_load_populatesPackages() async {
        let service = MockSubscriptionService()
        service.isConfigured = true
        service.offeringsToReturn = [
            SubscriptionOffering(id: "default", title: "Default", packages: [
                SubscriptionPackage(id: "pro.monthly", title: "Monthly", priceString: "$4.99")
            ])
        ]
        let manager = SubscriptionManager(service: service, cache: MemorySubscriptionCache(.none), eventBus: DomainEventBus())
        let vm = PaywallViewModel(providable: manager, manageable: manager)
        await vm.load()
        XCTAssertEqual(vm.packages.map(\.id), ["pro.monthly"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadWhenUnconfiguredSurfacesError() async {
        let service = MockSubscriptionService()
        service.isConfigured = false
        let manager = SubscriptionManager(service: service, cache: MemorySubscriptionCache(.none), eventBus: DomainEventBus())
        let vm = PaywallViewModel(providable: manager, manageable: manager)
        await vm.load()
        XCTAssertTrue(vm.packages.isEmpty)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_cancelPurchaseNoError() async {
        let service = MockSubscriptionService()
        service.isConfigured = true
        service.purchaseResult = .failure(SubscriptionOperationError.cancelled)
        let manager = SubscriptionManager(service: service, cache: MemorySubscriptionCache(.none), eventBus: DomainEventBus())
        let vm = PaywallViewModel(providable: manager, manageable: manager)
        vm.selectedPackage = SubscriptionPackage(id: "p", title: "t", priceString: "$1")
        await vm.purchaseSelected()
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isPremium)
    }
}