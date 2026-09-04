//
//  MainViewModelTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 04.09.2026.
//

import XCTest
@testable import MeditateAndNote

final class MainViewModelTests: XCTestCase {

    private func makeService(_ meditations: [Meditation]) -> MeditationService {
        StubMeditationService(meditations: meditations)
    }

    private func makeStore(lastSelected: MeditationID? = nil) -> MeditationSelectionStore {
        let suite = "MainViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = MeditationSelectionStore(defaults: defaults)
        store.lastSelectedID = lastSelected
        return store
    }

    private func testMeditation() -> Meditation {
        Meditation(id: "m1", title: MeditationTitle("Test"), breathingStyle: .box)
    }

    // MARK: - lastSelectedMeditation

    func testLastSelectedMeditation_noSelection_returnsNil() {
        let vm = MainViewModel(
            meditationService: makeService([testMeditation()]),
            selectionStore: makeStore(lastSelected: nil)
        )

        XCTAssertNil(vm.lastSelectedMeditation())
    }

    func testLastSelectedMeditation_matchedID_returnsMeditation() {
        let vm = MainViewModel(
            meditationService: makeService([testMeditation()]),
            selectionStore: makeStore(lastSelected: "m1")
        )

        XCTAssertEqual(vm.lastSelectedMeditation(), testMeditation())
    }

    func testLastSelectedMeditation_unknownID_returnsNil() {
        let vm = MainViewModel(
            meditationService: makeService([testMeditation()]),
            selectionStore: makeStore(lastSelected: "missing")
        )

        XCTAssertNil(vm.lastSelectedMeditation(), "An orphaned selection id yields no meditation")
    }
}

// MARK: - Test double

private struct StubMeditationService: MeditationService {
    let meditations: [Meditation]

    func getMeditations() -> [Meditation] { meditations }
}