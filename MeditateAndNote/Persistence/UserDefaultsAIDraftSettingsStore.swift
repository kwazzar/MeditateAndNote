//
//  UserDefaultsAIDraftSettingsStore.swift
//  MeditateAndNote
//
//  Infrastructure: AIDraftSettingsStore backed by UserDefaults + Keychain.
//

import Foundation

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
