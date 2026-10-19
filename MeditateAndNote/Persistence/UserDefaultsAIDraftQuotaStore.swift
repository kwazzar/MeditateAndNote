//
//  UserDefaultsAIDraftQuotaStore.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore

/// Lifetime free-generation counter for the AI draft quota.
final class UserDefaultsAIDraftQuotaStore: AIDraftQuotaStore, @unchecked Sendable {
    private static let storageKey = "aiDraftFreeGenerationsUsed"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // The counter is lifetime-scoped, so a simulator install reused by
        // several UI tests would exhaust the free allowance mid-suite.
        // `-resetAIDraftQuota` clears it on every launch.
        if ProcessInfo.processInfo.arguments.contains("-resetAIDraftQuota") {
            defaults.set(0, forKey: Self.storageKey)
        }
    }

    func used() -> Int {
        defaults.integer(forKey: Self.storageKey)
    }

    func record() {
        defaults.set(used() + 1, forKey: Self.storageKey)
    }
}
