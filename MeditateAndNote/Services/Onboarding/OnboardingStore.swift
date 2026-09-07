//
//  OnboardingStore.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import Foundation

// MARK: - OnboardingStore (persistence boundary / ACL)

/// Persistence contract for the onboarding completion flag.
/// Concrete stores live in Infrastructure (this file or Persistence/),
/// mimicking the `StreakActivityStore` / `UserDefaultsStreakStore` split.
protocol OnboardingStore {
    /// Whether the user has already finished (or skipped) onboarding.
    var hasCompletedOnboarding: Bool { get }
    /// Persists the fact that onboarding is done; next launch shows the tab bar.
    func markOnboardingCompleted()
}

// MARK: - UserDefaults implementation

/// UserDefaults-backed implementation of `OnboardingStore`.
final class UserDefaultsOnboardingStore: OnboardingStore {
    static let storageKey = "hasCompletedOnboarding"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Self.storageKey)
    }

    func markOnboardingCompleted() {
        defaults.set(true, forKey: Self.storageKey)
    }
}