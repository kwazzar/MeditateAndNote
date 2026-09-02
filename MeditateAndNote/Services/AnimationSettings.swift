//
//  AnimationSettings.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import Foundation
import OSLog

//MARK: - AnimationSettings

/// Persisted meditation-animation preference. Mirrors the `SoundSettings` /
/// `ThemeManager` pattern: an observable value backed by `UserDefaults`,
/// injected as a singleton via `shared`.
@Observable
final class AnimationSettings {
    static let shared = AnimationSettings()

    static let storageKey = "meditationAnimationStyle"

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "MeditateAndNote", category: "AnimationSettings")

    var style: BreathingAnimationStyle {
        get { storedStyle }
        set { storedStyle = newValue }
    }

    private var storedStyle: BreathingAnimationStyle {
        didSet {
            defaults.set(storedStyle.rawValue, forKey: Self.storageKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedRawValue = defaults.string(forKey: Self.storageKey)
        if let savedRawValue, BreathingAnimationStyle(rawValue: savedRawValue) == nil {
            logger.warning("Unknown stored animation style '\(savedRawValue)' — falling back to default")
        }
        self.storedStyle = BreathingAnimationStyle(rawValue: savedRawValue ?? "") ?? .path
    }
}