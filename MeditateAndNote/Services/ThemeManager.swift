//
//  ThemeManager.swift
//  MeditateAndNote
//
//  Created by kwazzar on 16.08.2026.
//

import SwiftUI
import OSLog

@Observable
final class ThemeManager {
    private static let storageKey = "selectedMainTheme"

    private let logger = Logger(subsystem: "MeditateAndNote", category: "ThemeManager")
    private let defaults: UserDefaults

    var current: MainTheme {
        didSet {
            defaults.set(current.rawValue, forKey: Self.storageKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedRawValue = defaults.string(forKey: Self.storageKey)
        if let savedRawValue, MainTheme(rawValue: savedRawValue) == nil {
            logger.warning("Unknown stored theme '\(savedRawValue)' — falling back to default")
        }
        self.current = MainTheme(rawValue: savedRawValue ?? "") ?? .liquidGlass
    }
}
