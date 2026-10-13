//
//  SubscriptionManaging.swift
//  MeditateAndNoteCore
//

import Foundation

/// Read side of subscriptions: the current status a ViewModel can display.
public protocol EntitlementProviding {
    var status: SubscriptionStatus { get }
    func isActive(_ entitlement: Entitlement) -> Bool
}

/// Write side of subscriptions, backed by a payment provider (RevenueCat).
/// These calls are the only transitions that may grant an entitlement.
public protocol SubscriptionManaging: Sendable {
    var isConfigured: Bool { get }
    func offerings() async throws -> [SubscriptionOffering]
    func purchase(_ package: SubscriptionPackage) async throws -> SubscriptionStatus
    func restore() async throws -> SubscriptionStatus
    func refresh() async -> SubscriptionStatus
}

public protocol SubscriptionProvidable: EntitlementProviding {}
public protocol SubscriptionManageable: SubscriptionManaging {}