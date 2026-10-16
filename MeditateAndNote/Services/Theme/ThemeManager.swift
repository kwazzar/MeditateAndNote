//
//  ThemeManager.swift
//  MeditateAndNote
//
//  Created by kwazzar on 16.08.2026.
//

import SwiftUI
import Observation
import MeditateAndNoteCore

@MainActor
@Observable
final class ThemeManager {
    private static let storageKey = "selectedMainTheme"

    private let logger = Logger(subsystem: "MeditateAndNote", category: "ThemeManager")
    private let defaults: UserDefaults
    /// Premium read for theme gating. `nil` (previews/tests) leaves every
    /// theme selectable — gating is enforced only when wired in production.
    private let entitlements: (any EntitlementProviding)?

    var current: MainTheme {
        didSet {
            defaults.set(current.rawValue, forKey: Self.storageKey)
        }
    }

    init(entitlements: (any EntitlementProviding)? = nil, defaults: UserDefaults = .standard) {
        self.entitlements = entitlements
        self.defaults = defaults
        let savedRawValue = defaults.string(forKey: Self.storageKey)
        if let savedRawValue, MainTheme(rawValue: savedRawValue) == nil {
            logger.warning("Unknown stored theme '\(savedRawValue)' — falling back to default")
        }
        // A persisted premium theme outlives a downgrade: clamp to the free
        // default so a lapsed user never renders a locked theme.
        let resolved = MainTheme(rawValue: savedRawValue ?? "") ?? .darkZen
        self.current = Self.clampIfLocked(resolved, entitlements: entitlements)
    }

    /// True when the theme needs premium and the entitlement isn't active.
    /// No provider attached (previews/tests) → nothing is locked.
    func isLocked(_ theme: MainTheme) -> Bool {
        guard let entitlements else { return false }
        return theme.isPremium && !entitlements.isActive(.pro)
    }

    /// The only sanctioned mutation path: locked themes are refused (the UI
    /// routes the tap to the paywall instead).
    func select(_ theme: MainTheme) {
        guard !isLocked(theme) else {
            logger.info("Theme '\(theme.rawValue)' locked — premium required")
            return
        }
        current = theme
    }

    private static func clampIfLocked(
        _ theme: MainTheme,
        entitlements: (any EntitlementProviding)?
    ) -> MainTheme {
        guard let entitlements, theme.isPremium, !entitlements.isActive(.pro) else { return theme }
        return .darkZen
    }
}
