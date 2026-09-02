//
//  SoundSettings.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import Foundation

//MARK: - SoundSettings

/// Persisted sound preferences for the meditation session. Mirrors the
/// `ThemeManager` / `MeditationSelectionStore` pattern: an observable value
/// backed by `UserDefaults`, injected as a singletons via `shared`.
@Observable
final class SoundSettings {
    static let shared = SoundSettings()

    static let storageKey = "meditationSoundVolume"

    private let defaults: UserDefaults

    var volume: Float {
        get { storedVolume }
        set { storedVolume = min(max(newValue, 0), 1) }
    }

    private var storedVolume: Float {
        didSet {
            defaults.set(storedVolume, forKey: Self.storageKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.object(forKey: Self.storageKey) as? Float
        self.storedVolume = min(max(saved ?? 0.2, 0), 1)
    }
}