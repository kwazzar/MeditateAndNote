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

    var current: MainTheme {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let savedRawValue = UserDefaults.standard.string(forKey: Self.storageKey)
        self.current = MainTheme(rawValue: savedRawValue ?? "") ?? .darkZen
    }
}
