//
//  AnimationSettingsTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 02.09.2026.
//

import XCTest
@testable import MeditateAndNote

final class AnimationSettingsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AnimationSettingsTests_\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultStyle_isPath() {
        let settings = AnimationSettings(defaults: defaults)
        XCTAssertEqual(settings.style, .path)
    }

    func testStyleRoundTripsThroughUserDefaults() {
        let settings = AnimationSettings(defaults: defaults)
        settings.style = .rings

        let reloaded = AnimationSettings(defaults: defaults)
        XCTAssertEqual(reloaded.style, .rings)
    }

    func testStoredUnknownValueFallsBackToPath() {
        defaults.set("nonexistent", forKey: AnimationSettings.storageKey)

        let settings = AnimationSettings(defaults: defaults)
        XCTAssertEqual(settings.style, .path)
    }
}