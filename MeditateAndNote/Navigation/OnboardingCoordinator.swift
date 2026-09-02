//
//  OnboardingCoordinator.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import Foundation

/// Coordinates the launch-time gating between the onboarding flow and the main
/// tab bar, plus the Router transition that runs when onboarding finishes.
///
/// Keeps startup gating out of the ViewModel (which must never touch a Router
/// or a concrete View) and out of RootContainer's body.
struct OnboardingCoordinator {
    private let store: any OnboardingStore

    init(store: any OnboardingStore) {
        self.store = store
    }

    /// True when a first-run user still has to go through onboarding.
    var shouldShowOnboarding: Bool {
        !store.hasCompletedOnboarding
    }

    /// Resets the root router to a clean default state right after onboarding
    /// finishes (Start or Skip), so the tab bar becomes the active interface.
    ///
    /// TODO: replay a pending launch deep link here if the app was opened via
    /// a scheme/universal link before onboarding completed.
    func onOnboardingCompleted(router: Router) {
        router.select(tab: .home)
        router.navigationStackPath = []
    }
}