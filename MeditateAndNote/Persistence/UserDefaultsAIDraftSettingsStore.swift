//
//  UserDefaultsAIDraftSettingsStore.swift
//  MeditateAndNote
//
//  Infrastructure: AIDraftSettingsStore backed by UserDefaults + Keychain.
//

import Foundation
import MeditateAndNoteCore

final class UserDefaultsAIDraftSettingsStore: HostedProviderSettings, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let keychain: any KeychainServiceProtocol
    /// The hosted provider this build points at. Empty when it points at
    /// none - and then the hosted provider is off for good.
    private let hostedEndpoint: String
    private let settingsKey = "com.meditateandnote.ai.settings"
    private let apiKeyAccount = "remote_llm_api_key"
    private let hostedProviderKey = "com.meditateandnote.ai.useHostedProvider"

    init(
        userDefaults: UserDefaults = .standard,
        keychain: any KeychainServiceProtocol = KeychainService(),
        hostedEndpoint: String = Config.aiDraftEndpoint
    ) {
        self.userDefaults = userDefaults
        self.keychain = keychain
        self.hostedEndpoint = hostedEndpoint
    }

    func useHostedProvider() -> Bool {
        guard !hostedEndpoint.isEmpty else { return false }
        // The default is the build's answer: a build that names a hosted
        // provider gets it until the user turns it off. The answer is only
        // stored when the user gives one.
        guard userDefaults.object(forKey: hostedProviderKey) != nil else { return true }
        return userDefaults.bool(forKey: hostedProviderKey)
    }

    func setUseHostedProvider(_ value: Bool) {
        userDefaults.set(value, forKey: hostedProviderKey)
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
