//
//  AIDraftSettings.swift
//  MeditateAndNote
//
//  Domain value object representing user settings for AI draft generation,
//  including remote fallback configuration and privacy preferences.
//

import Foundation
import Observation

struct AIDraftSettings: Equatable, Codable, Sendable {
    /// Whether to use remote API fallback when on-device AI (Foundation Models) is unavailable.
    /// Default is false for privacy-first opt-in.
    var useRemoteFallback: Bool
    
    /// Remote LLM provider endpoint URL (OpenAI / Anthropic compatible).
    var remoteEndpointURL: String
    
    /// Selected model for remote generation.
    var selectedModel: String
    
    /// Daily generation budget cap per user to prevent API cost runaway.
    var dailyGenerationLimit: Int

    static let defaultEndpointURL = "https://api.openai.com/v1/chat/completions"
    static let defaultModel = "gpt-4o-mini"
    static let defaultDailyLimit = 5

    init(
        useRemoteFallback: Bool = false,
        remoteEndpointURL: String = defaultEndpointURL,
        selectedModel: String = defaultModel,
        dailyGenerationLimit: Int = defaultDailyLimit
    ) {
        self.useRemoteFallback = useRemoteFallback
        self.remoteEndpointURL = remoteEndpointURL
        self.selectedModel = selectedModel
        self.dailyGenerationLimit = max(1, min(50, dailyGenerationLimit))
    }
}

// MARK: - Settings Store Protocol & Implementation

protocol AIDraftSettingsStore: Sendable {
    func loadSettings() -> AIDraftSettings
    func saveSettings(_ settings: AIDraftSettings)
    func getAPIKey() -> String?
    func saveAPIKey(_ key: String) throws
    func deleteAPIKey() throws
}

// MARK: - Observable Store Wrapper for SwiftUI

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

// MARK: - Settings Store Implementation

final class UserDefaultsAIDraftSettingsStore: AIDraftSettingsStore, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let keychain: any KeychainServiceProtocol
    private let settingsKey = "com.meditateandnote.ai.settings"
    private let apiKeyAccount = "remote_llm_api_key"

    init(
        userDefaults: UserDefaults = .standard,
        keychain: any KeychainServiceProtocol = KeychainService()
    ) {
        self.userDefaults = userDefaults
        self.keychain = keychain
    }

    func loadSettings() -> AIDraftSettings {
        guard let data = userDefaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AIDraftSettings.self, from: data) else {
            return AIDraftSettings()
        }
        return settings
    }

    func saveSettings(_ settings: AIDraftSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }

    func getAPIKey() -> String? {
        keychain.read(key: apiKeyAccount)
    }

    func saveAPIKey(_ key: String) throws {
        try keychain.save(key: apiKeyAccount, value: key)
    }

    func deleteAPIKey() throws {
        try keychain.delete(key: apiKeyAccount)
    }
}
