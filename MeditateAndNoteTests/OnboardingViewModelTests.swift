//
//  OnboardingViewModelTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 02.09.2026.
//

import XCTest
@testable import MeditateAndNote

@MainActor
final class OnboardingViewModelTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var completionCalled = false

    override func setUp() {
        super.setUp()
        suiteName = "OnboardingViewModelTests_\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        completionCalled = false
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeStore() -> OnboardingStore {
        UserDefaultsOnboardingStore(defaults: defaults)
    }

    private func makeSUT(pages: [OnboardingPage] = OnboardingPage.appSlides) -> OnboardingViewModel {
        OnboardingViewModel(
            store: makeStore(),
            pages: pages,
            onCompletion: { self.completionCalled = true }
        )
    }

    // MARK: - Initial state

    func testInitialState_startsOnFirstPage() {
        let vm = makeSUT()
        XCTAssertEqual(vm.currentPage, 0)
        XCTAssertEqual(vm.totalPages, 3)
        XCTAssertFalse(vm.isOnLastPage)
    }

    func testHasCompletedOnboarding_isFalseOnFirstLaunch() {
        let vm = makeSUT()
        XCTAssertFalse(vm.hasCompletedOnboarding)
    }

    // MARK: - Paging

    func testGoToNextPage_advancesUntilLastPage() {
        let vm = makeSUT()
        vm.goToNextPage()
        XCTAssertEqual(vm.currentPage, 1)
        vm.goToNextPage()
        XCTAssertEqual(vm.currentPage, 2)
        XCTAssertTrue(vm.isOnLastPage)
    }

    func testGoToNextPage_isClampedOnLastPage() {
        let vm = makeSUT(pages: OnboardingPage.appSlides)
        for _ in 0..<vm.totalPages { vm.goToNextPage() }
        XCTAssertEqual(vm.currentPage, vm.totalPages - 1)
    }

    func testGoToPreviousPage_isClampedToFirstPage() {
        let vm = makeSUT()
        vm.goToPreviousPage()
        XCTAssertEqual(vm.currentPage, 0)
    }

    // MARK: - Completion

    func testSkipPersistsFlagAndCallsCompletion() {
        let vm = makeSUT()
        vm.skip()
        XCTAssertTrue(vm.hasCompletedOnboarding)
        XCTAssertTrue(completionCalled)
        XCTAssertTrue(makeStore().hasCompletedOnboarding, "Flag must survive in the store")
    }

    func testStartOnLastPagePersistsFlagAndCallsCompletion() {
        let vm = makeSUT()
        vm.goToNextPage()
        vm.goToNextPage()
        vm.start()
        XCTAssertTrue(vm.hasCompletedOnboarding)
        XCTAssertTrue(completionCalled)
    }

    func testStartBeforeLastPage_doesNothing() {
        let vm = makeSUT()
        vm.start()
        XCTAssertFalse(vm.hasCompletedOnboarding)
        XCTAssertFalse(completionCalled)
    }
}