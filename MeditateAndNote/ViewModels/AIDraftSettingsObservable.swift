//
//  AIDraftSettingsObservable.swift
//  MeditateAndNote
//
//  Presentation-layer view model for AI draft settings.
//

import Foundation
import Observation

@MainActor @Observable final class AIDraftSettingsStoreObservable {
    var settings: AIDraftSettings
    var showAPIKeySheet = false
    /// Staging text for the key field. Memory-only — never persisted or
    /// logged. Lives here (not in view @State) so view-identity churn can't
    /// wipe typed/pasted text mid-entry.
    var draftAPIKey = ""

    private let store: any AIDraftSettingsStore

    init(store: any AIDraftSettingsStore = UserDefaultsAIDraftSettingsStore()) {
        self.store = store
        self.settings = store.loadSettings()
    }

    func loadSettings() -> AIDraftSettings {
        settings = store.loadSettings()
        return settings
    }

    func saveSettings(_ settings: AIDraftSettings) {
        self.settings = settings
        store.saveSettings(settings)
    }

    func getAPIKey() -> String? {
        store.getAPIKey()
    }

    func saveAPIKey(_ key: String) async throws {
        try store.saveAPIKey(key)
    }

    func deleteAPIKey() throws {
        try store.deleteAPIKey()
    }

    var apiKey: String? {
        get { store.getAPIKey() }
        set {
            guard let newValue else { return }
            try? store.saveAPIKey(newValue)
        }
    }
}
