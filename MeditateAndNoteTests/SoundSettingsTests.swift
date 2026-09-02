//
//  SoundSettingsTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 02.09.2026.
//

import XCTest
@testable import MeditateAndNote

final class SoundSettingsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SoundSettingsTests_\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultVolume_isPointTwo() {
        let settings = SoundSettings(defaults: defaults)
        XCTAssertEqual(settings.volume, 0.2, accuracy: 0.0001)
    }

    func testVolumeRoundTripsThroughUserDefaults() {
        let settings = SoundSettings(defaults: defaults)
        settings.volume = 0.75

        let reloaded = SoundSettings(defaults: defaults)
        XCTAssertEqual(reloaded.volume, 0.75, accuracy: 0.0001)
    }

    func testVolumeIsClampedToUpperBound() {
        let settings = SoundSettings(defaults: defaults)
        settings.volume = 1.5
        XCTAssertEqual(settings.volume, 1.0, accuracy: 0.0001)

        let reloaded = SoundSettings(defaults: defaults)
        XCTAssertEqual(reloaded.volume, 1.0, accuracy: 0.0001)
    }

    func testVolumeIsClampedToLowerBound() {
        let settings = SoundSettings(defaults: defaults)
        settings.volume = -0.5
        XCTAssertEqual(settings.volume, 0.0, accuracy: 0.0001)

        let reloaded = SoundSettings(defaults: defaults)
        XCTAssertEqual(reloaded.volume, 0.0, accuracy: 0.0001)
    }

    func testStoredOutOfRangeValueIsClampedOnLoad() {
        defaults.set(Float(3.0), forKey: SoundSettings.storageKey)

        let settings = SoundSettings(defaults: defaults)
        XCTAssertEqual(settings.volume, 1.0, accuracy: 0.0001)
    }
}