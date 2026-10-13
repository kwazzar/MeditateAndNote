//
//  SubscriptionStatus.swift
//  MeditateAndNoteCore
//

import Foundation

/// Server-verified subscription state. Only the RevenueCat adapter may *grant*
/// an entitlement; this value object just carries what the server reported.
///
/// `Codable` so the local cache can persist the last-known status for offline
/// display — the cache is a UX fast-path only and never an authority.
public struct SubscriptionStatus: Sendable, Equatable, Codable {
    public let activeEntitlements: Set<Entitlement>
    public let expirationDate: Date?
    public let willRenew: Bool
    public let productIdentifier: String?

    public static let none = SubscriptionStatus(
        activeEntitlements: [],
        expirationDate: nil,
        willRenew: false,
        productIdentifier: nil
    )

    public init(
        activeEntitlements: Set<Entitlement>,
        expirationDate: Date?,
        willRenew: Bool,
        productIdentifier: String?
    ) {
        self.activeEntitlements = activeEntitlements
        self.expirationDate = expirationDate
        self.willRenew = willRenew
        self.productIdentifier = productIdentifier
    }

    public func isActive(_ entitlement: Entitlement) -> Bool {
        activeEntitlements.contains(entitlement)
    }
}