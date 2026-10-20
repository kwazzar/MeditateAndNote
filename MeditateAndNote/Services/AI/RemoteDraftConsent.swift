//
//  RemoteDraftConsent.swift
//  MeditateAndNote
//
//  Whether the note text may leave the device.
//
//  The hosted provider answers on a server, so the note text goes with the
//  request. The user is told once, before the first such draft, and their
//  answer is remembered - a warning that repeats itself is noise, a warning
//  that never comes is not a warning.
//

import Foundation

@MainActor
final class RemoteDraftConsent {

    private let store: any HostedProviderSettings
    /// Whether the on-device model can answer. False means a remote provider
    /// answers, so the note text leaves the device.
    private let onDeviceAvailable: @Sendable () async -> Bool
    private let userDefaults: UserDefaults
    private let acknowledgedKey = "com.meditateandnote.ai.remoteDraftConsent"

    init(
        store: any HostedProviderSettings = UserDefaultsAIDraftSettingsStore(),
        onDeviceAvailable: @escaping @Sendable () async -> Bool = {
            await FoundationModelsAIDraftService().isAvailable
        },
        userDefaults: UserDefaults = .standard
    ) {
        self.store = store
        self.onDeviceAvailable = onDeviceAvailable
        self.userDefaults = userDefaults
    }

    /// True when the next draft would be answered off the device and the user
    /// has not been told yet.
    func requiresConsent() async -> Bool {
        guard remoteEnabled else { return false }
        guard !userDefaults.bool(forKey: acknowledgedKey) else { return false }
        return !(await onDeviceAvailable())
    }

    /// The user was told and agreed.
    func acknowledge() {
        userDefaults.set(true, forKey: acknowledgedKey)
    }

    /// The remote provider answers: the hosted proxy, or the user's own
    /// endpoint with the remote fallback on.
    var remoteEnabled: Bool {
        if store.useHostedProvider() { return true }
        let settings = store.loadSettings()
        return settings.useRemoteFallback && !settings.remoteEndpointURL.isEmpty
    }
}
