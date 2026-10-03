//
//  AnimationSettingsTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 02.09.2026.
//

import XCTest
@testable import MeditateAndNote
import MeditateAndNoteCore

@MainActor
final class AnimationSettingsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        await MainActor.run {
            suiteName = "AnimationSettingsTests_\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: suiteName)!
        }
        try await super.setUp()
    }

    override func tearDown() async throws {
        await MainActor.run {
            defaults.removePersistentDomain(forName: suiteName)
            defaults = nil
            suiteName = nil
        }
        try await super.tearDown()
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