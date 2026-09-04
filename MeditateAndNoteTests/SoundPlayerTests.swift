//
//  SoundPlayerTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 04.09.2026.
//

import XCTest
@testable import MeditateAndNote

// MARK: - Test doubles

final class MockAudioHandle: AudioPlayerHandle {
    var volume: Float = 0
    var currentTime: TimeInterval = 0
    private(set) var playCount = 0
    private(set) var prepareCount = 0

    func play() -> Bool { playCount += 1; return true }
    func prepareToPlay() -> Bool { prepareCount += 1; return true }
}

final class MockAudioResourceLoader: AudioResourceLoading {
    var handlesByResource: [String: MockAudioHandle] = [:]
    private(set) var requestedNames: [String] = []

    init(handlesByResource: [String: MockAudioHandle] = [:]) {
        self.handlesByResource = handlesByResource
    }

    func player(forResource name: String) -> AudioPlayerHandle? {
        requestedNames.append(name)
        return handlesByResource[name]
    }
}

final class SoundPlayerTests: XCTestCase {

    private func makeSettings(volume: Float) -> SoundSettings {
        let suite = "SoundPlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removeObject(forKey: SoundSettings.storageKey)
        let settings = SoundSettings(defaults: defaults)
        settings.volume = volume
        return settings
    }

    // MARK: - Play lifecycle

    func testPlay_setsVolumeFromSettings_resetsTime_andPlays() {
        let loader = MockAudioResourceLoader()
        let handle = MockAudioHandle()
        loader.handlesByResource["meditation_paused"] = handle

        let sut = SoundPlayer(soundSettings: makeSettings(volume: 0.7), resources: loader)
        sut.play(.paused)

        XCTAssertEqual(handle.volume, 0.7)
        XCTAssertEqual(handle.currentTime, 0)
        XCTAssertEqual(handle.playCount, 1)
        XCTAssertEqual(loader.requestedNames, ["meditation_paused"])
    }

    func testPlay_missingResource_isNoOp() {
        let loader = MockAudioResourceLoader()

        let sut = SoundPlayer(soundSettings: makeSettings(volume: 0.5), resources: loader)
        sut.play(.resumed)

        XCTAssertEqual(loader.requestedNames, ["meditation_resumed"])
        XCTAssertTrue(loader.handlesByResource.isEmpty)
    }

    func testPlay_reusesCachedPlayerForSameSound() {
        let handle = MockAudioHandle()
        let loader = MockAudioResourceLoader(handlesByResource: ["meditation_finished": handle])

        let sut = SoundPlayer(soundSettings: makeSettings(volume: 0.4), resources: loader)
        sut.play(.finished)
        sut.play(.finished)
        sut.play(.finished)

        XCTAssertEqual(loader.requestedNames, ["meditation_finished"],
                       "the resource loader is consulted only once per sound")
        XCTAssertEqual(handle.playCount, 3)
        XCTAssertEqual(handle.prepareCount, 1, "preparation happens once, on cache fill")
    }

    func testPlay_volumeIsClampedThroughSettings() {
        let handle = MockAudioHandle()
        let loader = MockAudioResourceLoader(handlesByResource: ["meditation_countdown": handle])

        let sut = SoundPlayer(soundSettings: makeSettings(volume: 1.5), resources: loader)
        sut.play(.countdownTick)

        XCTAssertEqual(handle.volume, 1.0, "volume above 1 must clamp to 1")
    }

    // MARK: - Resource name mapping

    func testResourceName_mappingForEverySoundCase() {
        let handlesByResource = [
            "meditation_paused": MockAudioHandle(),
            "meditation_resumed": MockAudioHandle(),
            "meditation_finished": MockAudioHandle(),
            "meditation_countdown": MockAudioHandle(),
            "breath_inhale": MockAudioHandle(),
            "breath_hold": MockAudioHandle(),
            "breath_exhale": MockAudioHandle(),
        ]
        let loader = MockAudioResourceLoader(handlesByResource: handlesByResource)

        let sut = SoundPlayer(soundSettings: makeSettings(volume: 0.3), resources: loader)
        sut.play(.paused)
        sut.play(.resumed)
        sut.play(.finished)
        sut.play(.countdownTick)
        sut.play(.phase(.inhale))
        sut.play(.phase(.holdAfterInhale))
        sut.play(.phase(.holdAfterExhale))
        sut.play(.phase(.exhale))

        // Both hold phases resolve to "breath_hold"; the second lookup reuses
        // the cached player, so the loader is consulted only once for it.
        XCTAssertEqual(loader.requestedNames, [
            "meditation_paused",
            "meditation_resumed",
            "meditation_finished",
            "meditation_countdown",
            "breath_inhale",
            "breath_hold",
            "breath_exhale",
        ])
    }
}