//
//  PremiumFeature.swift
//  MeditateAndNoteCore
//

import Foundation

/// The product surfaces a paywall protects. One entitlement (`.pro`) unlocks
/// all of them; the mapping lives here so feature→entitlement policy has a
/// single, testable home instead of scattered `isPremium` checks.
public enum PremiumFeature: String, Sendable, CaseIterable, Codable {
    case themes
    case meditationAnimation
    case insights

    public var requiredEntitlement: Entitlement { .pro }
}

@MainActor
public extension EntitlementProviding {
    /// Binary gate for the features above. Metered access (free AI-draft
    /// quota) is a separate domain rule — see `AIDraftQuota`.
    func canAccess(_ feature: PremiumFeature) -> Bool {
        isActive(feature.requiredEntitlement)
    }
}
