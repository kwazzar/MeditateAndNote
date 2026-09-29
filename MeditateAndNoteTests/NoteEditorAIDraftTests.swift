//
//  NoteEditorAIDraftTests.swift
//  MeditateAndNoteTests
//
//  The editor's ✨ button must generate against what the note says *now*.
//  The draft view model used to freeze its content at init, so a note that
//  was empty on the first tap kept asking bare questions forever even after
//  the user had written something.
//

import XCTest
@testable import MeditateAndNote

@MainActor
final class NoteEditorAIDraftTests: XCTestCase {

    private final class RecordingDrafts: AIDraftProvidable, AIDraftManageable {
        private(set) var requestedContexts: [NoteContent] = []
        private(set) var requestedInstructions: [String] = []
        private var session: AIDraftSession?

        func session(for noteID: NoteID) async throws -> AIDraftSession? { session }

        func startDraft(noteID: NoteID, instructions: String, context: NoteContent) async throws -> AIDraftSession {
            requestedContexts.append(context)
            requestedInstructions.append(instructions)
            let prompt = AIPrompt(instructions: instructions, noteID: noteID, context: context)
            var session = AIDraftSession(noteID: noteID, prompt: prompt)
            session.beginGeneration()
            session.fulfil(with: [AISuggestion(text: "s")])
            self.session = session
            return session
        }

        func regenerate(sessionID: UUID) async throws -> AIDraftSession { throw AIDraftError.noContext }
        func cancel(sessionID: UUID) async throws {}
        func discardSessions(for noteID: NoteID) async throws { session = nil }
        func acceptSuggestion(sessionID: UUID, suggestionID: UUID) async throws -> AIDraftSession { throw AIDraftError.noContext }
        func acceptAllSuggestions(sessionID: UUID) async throws -> AIDraftSession { throw AIDraftError.noContext }
        func rejectSuggestion(sessionID: UUID, suggestionID: UUID) async throws -> AIDraftSession { throw AIDraftError.noContext }
    }

    private func makeEditor(drafts: RecordingDrafts) -> NoteEditorViewModel {
        NoteEditorViewModel(notes: NoteServiceSpy(), drafts: drafts)
    }

    func testStartAIDraft_reusesCurrentBodyAfterTyping() async {
        let drafts = RecordingDrafts()
        let editor = makeEditor(drafts: drafts)

        // First tap on an empty note: asks questions, nothing to ground on.
        await editor.startAIDraft()
        XCTAssertEqual(drafts.requestedContexts, [NoteContent("")])

        // The user then writes.
        editor.body = "Slept badly, the review kept me up."

        await editor.startAIDraft()
        XCTAssertEqual(drafts.requestedContexts.last, NoteContent("Slept badly, the review kept me up."),
                       "✨ must generate against the body as it is now")
        XCTAssertEqual(editor.aiDraftViewModel?.canAccept, true,
                       "Text in the note means the result is insertable")
    }
}
