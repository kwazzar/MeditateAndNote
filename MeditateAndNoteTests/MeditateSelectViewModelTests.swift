//
//  MeditateSelectViewModelTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 04.09.2026.
//

import XCTest
@testable import MeditateAndNote

@MainActor
final class MeditateSelectViewModelTests: XCTestCase {

    private func makeService() -> MeditationService {
        StubMeditationService(meditations: [
            Meditation(id: "1", title: "A", breathingStyle: .box),
            Meditation(id: "2", title: "B", breathingStyle: .fourSevenEight),
        ])
    }

    private func makeStore() -> MeditationSelectionStore {
        let suite = "MeditateSelectViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return MeditationSelectionStore(defaults: defaults)
    }

    private func makeSUT(service: MeditationService? = nil,
                         store: MeditationSelectionStore? = nil) -> MeditateSelectViewModel {
        MeditateSelectViewModel(
            meditationService: service ?? makeService(),
            selectionStore: store ?? makeStore()
        )
    }

    /// The view model loads the catalogue asynchronously (500ms fake latency);
    /// keep pumping until the load lands.
    private func waitLoaded(_ vm: MeditateSelectViewModel) async {
        for _ in 0..<300 {
            if !vm.meditations.isEmpty { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: - Async load

    func testInit_isLoadingUntilCatalogueArrives() {
        let vm = makeSUT()

        XCTAssertTrue(vm.meditations.isEmpty, "Catalogue is empty while loading")
    }

    func testLoad_publishesCatalogue() async {
        let vm = makeSUT()

        await waitLoaded(vm)

        XCTAssertEqual(vm.meditations.map(\.id.rawValue), ["1", "2"])
    }

    func testLoad_withoutPriorSelection_selectsFirst() async {
        let vm = makeSUT()

        await waitLoaded(vm)

        XCTAssertEqual(vm.selectedMeditation?.id.rawValue, "1")
    }

    func testLoad_restoresPreviousSelection() async {
        let store = makeStore()
        store.lastSelectedID = "2"
        let vm = makeSUT(store: store)

        await waitLoaded(vm)

        XCTAssertEqual(vm.selectedMeditation?.id.rawValue, "2")
    }

    func testLoad_orphanedSelectionFallsBackToFirst() async {
        let store = makeStore()
        store.lastSelectedID = "999"
        let vm = makeSUT(store: store)

        await waitLoaded(vm)

        XCTAssertEqual(vm.selectedMeditation?.id.rawValue, "1", "Unknown stored id must not win")
        XCTAssertEqual(store.lastSelectedID?.rawValue, "1", "Falls back via save, not mutation")
    }

    func testLoad_stillLoading_afterReload() async {
        let vm = makeSUT()

        vm.loadMeditations()

        XCTAssertTrue(vm.meditations.isEmpty, "A fresh load resets the catalogue")
    }

    // MARK: - Selection

    func testSelectMeditation_keepsSelection_clearsInfo_andPersists() async {
        let store = makeStore()
        let vm = makeSUT(store: store)
        await waitLoaded(vm)
        let target = vm.meditations[1]

        vm.selectMeditation(target)

        XCTAssertEqual(vm.selectedMeditation, target)
        XCTAssertNil(vm.infoItem, "Selecting from the main list must dismiss the info sheet")
        XCTAssertEqual(store.lastSelectedID, target.id)
    }

    func testSelectMeditation_dismissesOpenInfoSheet() async {
        let vm = makeSUT()
        await waitLoaded(vm)
        vm.infoItem = MeditationInfoItem(meditation: vm.meditations[0])
        XCTAssertNotNil(vm.infoItem)

        vm.selectMeditation(vm.meditations[1])

        XCTAssertNil(vm.infoItem)
    }

    // MARK: - Start

    func testStartMeditation_withoutSelection_picksFirst() async {
        let store = makeStore()
        store.lastSelectedID = nil
        let vm = makeSUT(store: store)
        await waitLoaded(vm)
        vm.selectedMeditation = nil

        vm.startMeditation()

        XCTAssertEqual(vm.selectedMeditation?.id.rawValue, "1")
    }

    func testStartMeditation_withSelection_keepsIt() async {
        let vm = makeSUT()
        await waitLoaded(vm)

        vm.startMeditation()

        XCTAssertNotNil(vm.selectedMeditation)
    }

    // MARK: - Persistence

    func testSaveLastSelectedMeditation_writesStore() async {
        let store = makeStore()
        let vm = makeSUT(store: store)
        await waitLoaded(vm)
        let target = vm.meditations[1]

        vm.saveLastSelectedMeditation(target)

        XCTAssertEqual(store.lastSelectedID, target.id)
    }

    // MARK: - Info item

    func testInfoItem_isPresentable() async {
        let vm = makeSUT()
        await waitLoaded(vm)
        let item = MeditationInfoItem(meditation: vm.meditations[0])

        XCTAssertEqual(item.id, vm.meditations[0].id, "The info item identity is the meditation id")
    }
}

// MARK: - Test double

private struct StubMeditationService: MeditationService {
    let meditations: [Meditation]

    func getMeditations() -> [Meditation] { meditations }
}