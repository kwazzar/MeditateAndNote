import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

@MainActor
final class SubscriptionViewModelTests: XCTestCase {
    func test_isPremiumReflectsProvider() {
        let service = MockSubscriptionService()
        service.isConfigured = true
        let manager = SubscriptionManager(service: service, cache: MemorySubscriptionCache(.none), eventBus: DomainEventBus())
        let vm = SubscriptionViewModel(providable: manager, manageable: manager)
        XCTAssertFalse(vm.isPremium)
    }

    func test_restoreCancelledSetsNoError() async {
        let service = MockSubscriptionService()
        service.restoreError = SubscriptionOperationError.cancelled
        let manager = SubscriptionManager(service: service, cache: MemorySubscriptionCache(.none), eventBus: DomainEventBus())
        let vm = SubscriptionViewModel(providable: manager, manageable: manager)
        await vm.restore()
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isBusy)
    }

    func test_restoreFailureShowsError() async {
        let service = MockSubscriptionService()
        service.restoreError = SubscriptionOperationError.restoreFailed
        let manager = SubscriptionManager(service: service, cache: MemorySubscriptionCache(.none), eventBus: DomainEventBus())
        let vm = SubscriptionViewModel(providable: manager, manageable: manager)
        await vm.restore()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isBusy)
    }
}