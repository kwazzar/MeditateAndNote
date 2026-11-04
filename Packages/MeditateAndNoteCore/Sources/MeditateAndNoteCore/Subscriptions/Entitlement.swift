//
//  Entitlement.swift
//  MeditateAndNoteCore
//

import Foundation

/// The paid features a user can unlock. Mirrored on Android, so entitlement
/// checks stay consistent across platforms.
///
/// The raw value is the app's own domain identity, not the RevenueCat
/// identifier: the dashboard spells the paid entitlement `premium` (see
/// `Config.proEntitlementID` on iOS and
/// `RevenueCatPurchasesService.PREMIUM_ENTITLEMENT_ID` on Android), and each
/// provider maps its spelling onto this type.
public enum Entitlement: String, Sendable, CaseIterable, Codable {
    case pro
}