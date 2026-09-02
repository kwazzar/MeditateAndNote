//
//  OnboardingViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import Foundation
import Observation
import OSLog

/// Orchestrates the onboarding flow: current page, paging and completion state.
/// Writes the completion flag through `OnboardingStore`; never touches a Router
/// or a concrete View — the Router transition is owned by `OnboardingCoordinator`.
@MainActor
@Observable
final class OnboardingViewModel {
    private let logger = Logger(subsystem: Config.bundleID, category: "OnboardingViewModel")

    // MARK: - Dependencies

    private let store: any OnboardingStore
    private let onCompletion: () -> Void

    // MARK: - State

    var currentPage: Int = 0
    let pages: [OnboardingPage]

    // MARK: - Derived state

    var totalPages: Int { pages.count }
    /// True on the last slide — the footer button becomes "Почати".
    var isOnLastPage: Bool { currentPage >= totalPages - 1 }
    /// Read-through of the persisted flag (used by tests and previews).
    var hasCompletedOnboarding: Bool { store.hasCompletedOnboarding }

    init(store: any OnboardingStore,
         pages: [OnboardingPage],
         onCompletion: @escaping () -> Void) {
        self.store = store
        self.pages = pages
        self.onCompletion = onCompletion
    }

    // MARK: - Page navigation

    func goToNextPage() {
        guard !isOnLastPage else { return }
        currentPage += 1
    }

    func goToPreviousPage() {
        currentPage = max(0, currentPage - 1)
    }

    // MARK: - Completion

    /// "Пропустити" — available on every page.
    func skip() {
        completeOnboarding()
    }

    /// "Почати" — only meaningful on the last page.
    func start() {
        guard isOnLastPage else { return }
        completeOnboarding()
    }

    private func completeOnboarding() {
        store.markOnboardingCompleted()
        logger.info("Onboarding finished, moving to the main app")
        onCompletion()
    }
}