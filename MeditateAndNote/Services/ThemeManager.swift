//
//  ThemeManager.swift
//  MeditateAndNote
//
//  Created by kwazzar on 16.08.2026.
//

import SwiftUI

@Observable
final class ThemeManager {
    private static let storageKey = "selectedMainTheme"

    private let defaults: UserDefaults

    var current: MainTheme {
        didSet {
            defaults.set(current.rawValue, forKey: Self.storageKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedRawValue = defaults.string(forKey: Self.storageKey)
        self.current = MainTheme(rawValue: savedRawValue ?? "") ?? .liquidGlass
    }
}
