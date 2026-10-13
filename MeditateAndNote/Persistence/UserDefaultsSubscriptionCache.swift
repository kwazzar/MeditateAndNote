//
//  UserDefaultsSubscriptionCache.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore

/// Persists the last-known `SubscriptionStatus` for offline/fast startup.
/// UX fast-path only — corrupted or missing data degrades to nil (free),
/// and it is never an authority for granting an entitlement.
final class UserDefaultsSubscriptionCache: SubscriptionCache, @unchecked Sendable {
    private static let key = "subscription.status.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SubscriptionStatus? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(SubscriptionStatus.self, from: data)
    }

    func save(_ status: SubscriptionStatus) {
        guard let data = try? JSONEncoder().encode(status) else { return }
        defaults.set(data, forKey: Self.key)
    }
}