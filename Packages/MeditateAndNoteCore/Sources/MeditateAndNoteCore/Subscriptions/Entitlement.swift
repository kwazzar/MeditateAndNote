//
//  Entitlement.swift
//  MeditateAndNoteCore
//

import Foundation

/// The paid features a user can unlock. Mirrored on Android with the same
/// identifiers, so entitlement checks stay consistent across platforms.
public enum Entitlement: String, Sendable, CaseIterable, Codable {
    case pro
}