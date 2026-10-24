//
//  ReaderSettings.swift
//  MeditateAndNote
//
//  Persisted reader appearance (font size, paper theme). Separate from the
//  app-wide ThemeManager on purpose: the reader has its own paper colors.
//

import Foundation
import Observation
import SwiftUI

enum ReaderTheme: String, CaseIterable, Identifiable {
    case light
    case sepia
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    var background: Color {
        switch self {
        case .light: Color(red: 0.98, green: 0.98, blue: 0.97)
        case .sepia: Color(red: 0.96, green: 0.92, blue: 0.82)
        case .dark: Color(red: 0.09, green: 0.09, blue: 0.10)
        }
    }

    var text: Color {
        switch self {
        case .light: Color(red: 0.12, green: 0.12, blue: 0.13)
        case .sepia: Color(red: 0.22, green: 0.16, blue: 0.10)
        case .dark: Color(red: 0.88, green: 0.87, blue: 0.85)
        }
    }

    var secondaryText: Color {
        switch self {
        case .light: Color(red: 0.45, green: 0.45, blue: 0.46)
        case .sepia: Color(red: 0.48, green: 0.40, blue: 0.32)
        case .dark: Color(red: 0.60, green: 0.59, blue: 0.58)
        }
    }
}

@MainActor
@Observable
final class ReaderSettings {
    static let shared = ReaderSettings()

    static let fontSizeKey = "readerFontSize"
    static let themeKey = "readerTheme"
    static let scrollModeKey = "readerScrollMode"
    static let defaultFontSize: CGFloat = 18
    static let fontSizeRange: ClosedRange<CGFloat> = 12...32

    private let defaults: UserDefaults

    var fontSize: CGFloat {
        didSet { defaults.set(fontSize, forKey: Self.fontSizeKey) }
    }

    var theme: ReaderTheme {
        didSet { defaults.set(theme.rawValue, forKey: Self.themeKey) }
    }

    var scrollMode: Bool {
        didSet { defaults.set(scrollMode, forKey: Self.scrollModeKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedSize = defaults.object(forKey: Self.fontSizeKey) as? CGFloat
        self.fontSize = storedSize.map { min(max($0, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound) }
            ?? Self.defaultFontSize
        self.theme = ReaderTheme(rawValue: defaults.string(forKey: Self.themeKey) ?? "") ?? .sepia
        self.scrollMode = defaults.bool(forKey: Self.scrollModeKey)
    }
}
