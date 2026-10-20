//
//  AIDraftSettingsObservable.swift
//  MeditateAndNote
//
//  Presentation-layer view model for AI draft settings.
//

import Foundation
import Observation
import MeditateAndNoteCore

@MainActor @Observable final class AIDraftSettingsStoreObservable {
    var settings: AIDraftSettings
    var showAPIKeySheet = false
    /// Whether the hosted provider (our proxy) answers the drafts. It is the
    /// build's answer until the user gives one.
    private(set) var useHostedProvider: Bool
    /// The hosted endpoint this build points at. Empty when it points at
    /// none - then the hosted provider is off and the user's own endpoint
    /// is the only way to a remote answer.
    let hostedEndpoint: String
    /// Staging text for the key field. Memory-only — never persisted or
    /// logged. Lives here (not in view @State) so view-identity churn can't
    /// wipe typed/pasted text mid-entry.
    var draftAPIKey = ""

    private let store: any HostedProviderSettings

    init(store: any HostedProviderSettings = UserDefaultsAIDraftSettingsStore()) {
        self.store = store
        self.settings = store.loadSettings()
        self.useHostedProvider = store.useHostedProvider()
        self.hostedEndpoint = Config.aiDraftEndpoint
    }

    /// The user's answer to "the hosted provider answers the drafts".
    func setUseHostedProvider(_ value: Bool) {
        useHostedProvider = value
        store.setUseHostedProvider(value)
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
