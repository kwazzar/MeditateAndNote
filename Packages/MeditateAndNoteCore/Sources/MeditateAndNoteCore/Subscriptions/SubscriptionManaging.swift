//
//  SubscriptionManaging.swift
//  MeditateAndNoteCore
//

import Foundation

/// Read side of subscriptions: the current status a ViewModel can display.
@MainActor
public protocol EntitlementProviding {
    var status: SubscriptionStatus { get }
    func isActive(_ entitlement: Entitlement) -> Bool
}

/// Write side of subscriptions, backed by a payment provider (RevenueCat).
/// These calls are the only transitions that may grant an entitlement.
@MainActor
public protocol SubscriptionManaging {
    var isConfigured: Bool { get }
    func offerings() async throws -> [SubscriptionOffering]
    func purchase(_ package: SubscriptionPackage) async throws -> SubscriptionStatus
    func restore() async throws -> SubscriptionStatus
    /// Returns the provider's current status, or `nil` when it could not be
    /// determined (e.g. offline with no cached data). `nil` must never be
    /// treated as "free" — callers keep their last known status.
    func refresh() async -> SubscriptionStatus?
}

@MainActor
public protocol SubscriptionProvidable: EntitlementProviding {}

@MainActor
public protocol SubscriptionManageable: SubscriptionManaging {}