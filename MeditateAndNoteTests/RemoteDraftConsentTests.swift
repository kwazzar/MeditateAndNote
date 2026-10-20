//
//  RemoteDraftConsentTests.swift
//  MeditateAndNoteTests
//
//  The note text leaves the device when a remote provider answers. These
//  tests hold the question: the user is asked when a remote provider
//  answers and the on-device model cannot, and only then.
//

import XCTest
@testable import MeditateAndNote
import MeditateAndNoteCore

private struct StubHostedStore: HostedProviderSettings {
    let settings: AIDraftSettings
    let useHosted: Bool

    init(settings: AIDraftSettings, useHosted: Bool) {
        self.settings = settings
        self.useHosted = useHosted
    }

    func loadSettings() -> AIDraftSettings { settings }
    func saveSettings(_ settings: AIDraftSettings) {}
    func getAPIKey() -> String? { nil }
    func saveAPIKey(_ key: String) throws {}
    func deleteAPIKey() throws {}
    func useHostedProvider() -> Bool { useHosted }
    func setUseHostedProvider(_ value: Bool) {}
}

final class RemoteDraftConsentTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "RemoteDraftConsentTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    @MainActor
    private func makeConsent(
        useHosted: Bool = true,
        settings: AIDraftSettings = AIDraftSettings(),
        onDeviceAvailable: Bool = false
    ) -> RemoteDraftConsent {
        RemoteDraftConsent(
            store: StubHostedStore(settings: settings, useHosted: useHosted),
            onDeviceAvailable: { onDeviceAvailable },
            userDefaults: defaults
        )
    }

    @MainActor
    func test_requiresConsent_remoteAnswersOnDeviceCannot_asks() async {
        let consent = makeConsent(useHosted: true, onDeviceAvailable: false)
        let asks = await consent.requiresConsent()
        XCTAssertTrue(asks)
    }

    @MainActor
    func test_requiresConsent_onDeviceAnswers_doesNotAsk() async {
        let consent = makeConsent(useHosted: true, onDeviceAvailable: true)
        let asks = await consent.requiresConsent()
        XCTAssertFalse(asks)
    }

    @MainActor
    func test_requiresConsent_noRemoteProvider_doesNotAsk() async {
        let consent = makeConsent(
            useHosted: false,
            settings: AIDraftSettings(useRemoteFallback: false),
            onDeviceAvailable: false
        )
        let asks = await consent.requiresConsent()
        XCTAssertFalse(asks)
    }

    @MainActor
    func test_requiresConsent_ownEndpointWithRemoteOn_asks() async {
        let consent = makeConsent(
            useHosted: false,
            settings: AIDraftSettings(
                useRemoteFallback: true,
                remoteEndpointURL: "https://own.example.com/v1/chat/completions"
            ),
            onDeviceAvailable: false
        )
        let asks = await consent.requiresConsent()
        XCTAssertTrue(asks)
    }

    @MainActor
    func test_acknowledge_stopsTheQuestion() async {
        let consent = makeConsent(useHosted: true, onDeviceAvailable: false)
        consent.acknowledge()
        let asks = await consent.requiresConsent()
        XCTAssertFalse(asks)
    }
}
