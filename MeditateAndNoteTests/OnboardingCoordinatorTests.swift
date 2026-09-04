//
//  OnboardingCoordinatorTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 04.09.2026.
//

import XCTest
@testable import MeditateAndNote

private final class StubOnboardingStore: OnboardingStore {
    var hasCompletedOnboarding: Bool = false
    private(set) var markCount = 0

    func markOnboardingCompleted() {
        markCount += 1
        hasCompletedOnboarding = true
    }
}

final class OnboardingCoordinatorTests: XCTestCase {

    func testShouldShowOnboarding_whenStoreNotCompleted_isTrue() {
        let store = StubOnboardingStore()
        let coordinator = OnboardingCoordinator(store: store)

        XCTAssertTrue(coordinator.shouldShowOnboarding)
    }

    func testShouldShowOnboarding_whenStoreCompleted_isFalse() {
        let store = StubOnboardingStore()
        store.hasCompletedOnboarding = true
        let coordinator = OnboardingCoordinator(store: store)

        XCTAssertFalse(coordinator.shouldShowOnboarding)
    }

    func testOnOnboardingCompleted_selectsHomeAndClearsPath() {
        let coordinator = OnboardingCoordinator(store: StubOnboardingStore())
        let router = Router(level: 0, identifierTab: nil)
        router.navigationStackPath = [.settings]
        XCTAssertEqual(router.navigationStackPath.count, 1)

        coordinator.onOnboardingCompleted(router: router)

        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertEqual(router.navigationStackPath, [])
    }
}