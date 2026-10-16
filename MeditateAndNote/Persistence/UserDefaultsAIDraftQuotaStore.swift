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
    }

    func used() -> Int {
        defaults.integer(forKey: Self.storageKey)
    }

    func record() {
        defaults.set(used() + 1, forKey: Self.storageKey)
    }
}
