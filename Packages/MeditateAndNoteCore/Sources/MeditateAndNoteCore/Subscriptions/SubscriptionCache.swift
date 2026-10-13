//
//  SubscriptionCache.swift
//  MeditateAndNoteCore
//

import Foundation

/// Last-known subscription status persisted locally for offline/fast startup.
/// The cache is NEVER an authority: it may seed the UI, but only a refresh
/// through `SubscriptionManaging` may grant or revoke an entitlement.
public protocol SubscriptionCache: Sendable {
    func load() -> SubscriptionStatus?
    func save(_ status: SubscriptionStatus)
}