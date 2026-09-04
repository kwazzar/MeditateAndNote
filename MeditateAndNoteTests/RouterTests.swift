//
//  RouterTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 04.09.2026.
//

import XCTest
@testable import MeditateAndNote

@MainActor
final class RouterTests: XCTestCase {

    private func makeRoot() -> Router {
        let root = Router(level: 0, identifierTab: nil)
        root.selectedTab = .home
        return root
    }

    // MARK: - Stack pushes

    func testPush_appendsToNavigationPath() {
        let router = Router(level: 1, identifierTab: .notes)
        router.push(.settings)
        router.push(.readingView)
        XCTAssertEqual(router.navigationStackPath, [.settings, .readingView])
    }

    func testNavigate_push_routesOntoStack() {
        let router = Router(level: 1, identifierTab: .home)
        router.navigate(to: .push(.streakDetail))
        XCTAssertEqual(router.navigationStackPath, [.streakDetail])
    }

    func testNavigate_sheet_setsThenReplacesPresentingSheet() {
        let router = Router(level: 1, identifierTab: .home)
        router.navigate(to: .sheet(.newNote))
        XCTAssertEqual(router.presentingSheet, .newNote)

        router.navigate(to: .sheet(.timeMeditation))
        XCTAssertEqual(router.presentingSheet, .timeMeditation, "only one sheet at a time")
    }

    func testNavigate_fullScreen_setsPresentingFullScreen() {
        let router = Router(level: 1, identifierTab: .home)
        let id = MeditationID(rawValue: "abc")
        router.navigate(to: .fullScreen(.meditationSession(id: id)))
        XCTAssertEqual(router.presentingFullScreen, .meditationSession(id: id))
    }

    // MARK: - Tab selection

    func testSelectTab_onRoot_setsSelectedTab() {
        let root = makeRoot()
        root.select(tab: .notes)
        XCTAssertEqual(root.selectedTab, .notes)
    }

    func testSelectTab_onChild_propagatesToRootAndClearsChildContent() {
        let root = makeRoot()
        let child = root.childRouter(for: .notes)
        child.push(.settings)
        child.present(sheet: .newNote)
        child.present(fullScreen: .fullScreenNote(id: NoteID()))

        child.select(tab: .meditations)

        XCTAssertEqual(root.selectedTab, .meditations)
        XCTAssertTrue(child.navigationStackPath.isEmpty, "switching tabs must clear the child stack")
        XCTAssertNil(child.presentingSheet)
        XCTAssertNil(child.presentingFullScreen)
    }

    // MARK: - Hierarchy & active tracking

    func testChildRouter_incrementsLevelAndLinksParent() {
        let root = makeRoot()
        let child = root.childRouter(for: .meditations)
        XCTAssertEqual(child.level, 1)
        XCTAssertEqual(child.identifierTab, .meditations)
        XCTAssertTrue(child.parent === root)
    }

    func testChildRouter_inheritsTabWhenNotOverridden() {
        let root = Router(level: 0, identifierTab: .notes)
        let child = root.childRouter()
        XCTAssertEqual(child.identifierTab, .notes)
    }

    func testSetResignActive_tracksSingleActiveRouter() {
        let root = makeRoot()
        let child = root.childRouter(for: .notes)

        root.setActive()
        XCTAssertTrue(root.isActive)
        XCTAssertFalse(child.isActive)

        child.setActive()
        XCTAssertTrue(child.isActive)
        XCTAssertFalse(root.isActive, "only one router in a chain is active")
    }

    func testDeepLinkOpen_inactiveRouter_ignoresDestination() {
        let root = makeRoot()
        let child = root.childRouter(for: .notes)
        child.deepLinkOpen(to: .push(.settings))
        XCTAssertTrue(child.navigationStackPath.isEmpty)
    }

    func testDeepLinkOpen_activeRouter_navigates() {
        let root = makeRoot()
        let child = root.childRouter(for: .notes)
        child.setActive()

        child.deepLinkOpen(to: .push(.noteDetails(noteId: NoteID())))
        XCTAssertEqual(child.navigationStackPath.count, 1)
    }

    func testNavigate_tab_routesToSelectedTab() {
        let root = makeRoot()

        root.navigate(to: .tab(.meditations))

        XCTAssertEqual(root.selectedTab, .meditations)
    }

    func testPresent_sheet_directly_setsPresentingSheet() {
        let router = Router(level: 1, identifierTab: .home)

        router.present(sheet: .newNote)

        XCTAssertEqual(router.presentingSheet, .newNote)
    }

    func testPresent_fullScreen_directly_setsPresentingFullScreen() {
        let router = Router(level: 1, identifierTab: .home)
        let session = FullScreenDestination.meditationSession(id: MeditationID(rawValue: "x"))

        router.present(fullScreen: session)

        XCTAssertEqual(router.presentingFullScreen, session)
    }

    func testPreviewRouter_isLevelZero() {
        let router = Router.previewRouter()
        XCTAssertEqual(router.level, 0)
        XCTAssertNil(router.identifierTab)
    }

    func testResignActive_topLevel_isNoOp() {
        let root = makeRoot()
        root.setActive()

        root.resignActive()

        XCTAssertFalse(root.isActive, "Top level has no parent to fall back to")
    }
}

// MARK: - DeepLink parsing

final class DeepLinkParserTests: XCTestCase {

    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    // MARK: - fullComponents

    func testFullComponents_splitsPathIgnoringScheme() {
        XCTAssertEqual(url("meditateandnote://meditation/123").fullComponents, ["meditation", "123"])
    }

    func testFullComponents_singleComponent() {
        XCTAssertEqual(url("meditateandnote://home").fullComponents, ["home"])
    }

    func testFullComponents_withoutScheme_isEmpty() {
        XCTAssertEqual(URL(string: "meditation/new")?.fullComponents, [])
    }

    // MARK: - registered parsers

    func testDestination_homeTabDeepLink() throws {
        XCTAssertEqual(DeepLink.destination(from: url("meditateandnote://home")), .tab(.home))
    }

    func testDestination_newNoteSheet() throws {
        XCTAssertEqual(DeepLink.destination(from: url("meditateandnote://note/new")), .sheet(.newNote))
    }

    func testDestination_newMeditationSheet() throws {
        XCTAssertEqual(DeepLink.destination(from: url("meditateandnote://meditation/new")), .sheet(.meditationSettings))
    }

    func testDestination_unknownPath_returnsNil() {
        XCTAssertNil(DeepLink.destination(from: url("meditateandnote://bogus")))
        XCTAssertNil(DeepLink.destination(from: url("meditateandnote://note/edit")))
        XCTAssertNil(DeepLink.destination(from: url("meditateandnote://note/new/extra")))
    }

    func testDestination_foreignScheme_returnsNil() {
        XCTAssertNil(DeepLink.destination(from: url("https://meditateandnote.com/home")))
    }

    // MARK: - static parsers

    func testMeditationSettingsParser() {
        let parser = DeepLinkParser.meditationSettings
        XCTAssertEqual(parser.parse(url("meditateandnote://meditation/settings")), .sheet(.meditationSettings))
        XCTAssertNil(parser.parse(url("meditateandnote://meditation")))
        XCTAssertNil(parser.parse(url("meditateandnote://meditation/settings/extra")))
        XCTAssertNil(parser.parse(url("meditateandnote://note/settings")))
    }

    func testNewNoteParser() {
        let parser = DeepLinkParser.newNote
        XCTAssertEqual(parser.parse(url("meditateandnote://note/new")), .sheet(.newNote))
        XCTAssertNil(parser.parse(url("meditateandnote://note")))
        XCTAssertNil(parser.parse(url("meditateandnote://meditation/new")))
    }

    // MARK: - equal(to:) combinator

    func testEqualParser_matchesOnlyExactComponents() {
        let parser = DeepLinkParser.equal(to: ["a", "b"], destination: .push(.settings))
        XCTAssertEqual(parser.parse(url("meditateandnote://a/b")), .push(.settings))
        XCTAssertNil(parser.parse(url("meditateandnote://a")))
        XCTAssertNil(parser.parse(url("meditateandnote://a/b/c")))
    }
}

// MARK: - Destination value semantics

final class DestinationTests: XCTestCase {

    func testDestinationDescriptions() {
        XCTAssertEqual(Destination.tab(.home).description, ".tab(home)")
        XCTAssertEqual(Destination.push(.readingView).description, ".push(.readingView)")
        XCTAssertEqual(Destination.sheet(.newNote).description, ".sheet(.newNote)")
        let session = FullScreenDestination.meditationSession(id: "m1")
        XCTAssertEqual(Destination.fullScreen(session).description, ".fullScreen(\(session))")
    }

    func testPushDestinationDescriptions() {
        let noteId = NoteID()
        let sample = Meditation(id: "m1", title: "Calm", breathingStyle: .box)
        XCTAssertEqual(PushDestination.newNote.description, ".newNote")
        XCTAssertEqual(PushDestination.noteDetails(noteId: noteId).description, ".noteDetails(\(noteId))")
        XCTAssertEqual(PushDestination.streakDetail.description, ".streakDetail")
        XCTAssertEqual(PushDestination.settings.description, ".settings")
        XCTAssertEqual(PushDestination.meditation(sample).description, ".meditation(\(sample))")
        let completion = PushDestination.meditationCompletion(meditation: sample, duration: .oneMin)
        XCTAssertEqual(completion.description, ".meditationCompletion(\(sample), \(MeditationDuration.oneMin.rawValue)s)")
    }

    func testSheetDestinationIdentifiability() {
        XCTAssertEqual(SheetDestination.newNote.id, "newNote")
        XCTAssertEqual(SheetDestination.meditationSettings.id, "meditationSettings")
        XCTAssertEqual(SheetDestination.timeMeditation.id, ".timeMeditation")
    }

    func testFullScreenDestinationIdentifiability() {
        let noteId = NoteID()
        let medId = MeditationID(rawValue: "m2")
        XCTAssertEqual(FullScreenDestination.meditationSession(id: medId).id, "meditationSession_\(medId)")
        XCTAssertEqual(FullScreenDestination.fullScreenNote(id: noteId).id, "fullScreenNote_\(noteId)")
    }

    func testDestinations_hashDistinctPayloads() {
        XCTAssertNotEqual(Destination.push(.noteDetails(noteId: NoteID())),
                          Destination.push(.noteDetails(noteId: NoteID())))
        XCTAssertNotEqual(Destination.fullScreen(.meditationSession(id: "a")),
                          Destination.fullScreen(.meditationSession(id: "b")))
        XCTAssertEqual(Set([Destination.tab(.home), Destination.tab(.home)]).count, 1)
    }
}
