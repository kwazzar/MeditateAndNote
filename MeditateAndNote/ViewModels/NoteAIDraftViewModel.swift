//
//  NoteAIDraftViewModel.swift
//  MeditateAndNote
//
//  Presentation state machine for the "Help me write" AI sheet. Depends on the
//  AIDraftProvidable/AIDraftManageable protocols — never on AIDraftManager
//  directly. Inserts suggestions back into the editor via an `onInsert`
//  callback so the editor (not the sheet) owns its own body/title mutation.
//

import Foundation
import Observation

@MainActor
@Observable
final class NoteAIDraftViewModel {

    // MARK: - Observable UI state

    enum UIState: Equatable {
        case idle
        case loading
        case ready
        case unavailable
        case failed(AIDraftError)
    }

    private(set) var uiState: UIState = .idle
    private(set) var sessions: [AIDraftSession] = []
    private(set) var lastError: AIDraftError?

    /// Fired with the chosen suggestion when the user taps "Insert".
    var onInsert: ((AIDraftSession, AISuggestion) -> Void)?

    // MARK: - Dependencies

    private let noteID: NoteID
    private let currentContent: NoteContent
    private let drafts: any AIDraftProvidable & AIDraftManageable

    init(
        noteID: NoteID,
        currentContent: NoteContent,
        drafts: any AIDraftProvidable & AIDraftManageable
    ) {
        self.noteID = noteID
        self.currentContent = currentContent
        self.drafts = drafts
    }

    // MARK: - Actions

    /// Kicks off a generation. If a terminal session already exists for this
    /// note it is returned instead of spawning a duplicate.
    func start(instructions: String = "Give me ideas to continue this note") async {
        do {
            if let existing = try await drafts.session(for: noteID) {
                if existing.state == .ready {
                    uiState = .ready
                    sessions = [existing]
                    return
                }
            }

            uiState = .loading
            let session = try await drafts.startDraft(
                noteID: noteID,
                instructions: instructions,
                context: currentContent
            )
            sessions = [session]
            uiState = session.state == .ready ? .ready : .failed(.noContext)
            lastError = nil
        } catch let error as AIDraftError {
            handleGenerationFailure(error)
        } catch {
            handleGenerationFailure(.emptyResponse)
        }
    }

    /// Re-run generation for a stale session.
    func regenerate(_ session: AIDraftSession) async {
        guard isTerminal(session) else { return }
        uiState = .loading
        do {
            let refreshed = try await drafts.regenerate(sessionID: session.id)
            sessions = [refreshed]
            uiState = refreshed.state == .ready ? .ready : .failed(.noContext)
            lastError = nil
        } catch let error as AIDraftError {
            handleGenerationFailure(error)
        } catch {
            handleGenerationFailure(.emptyResponse)
        }
    }

    func cancel(_ session: AIDraftSession) async {
        do {
            try await drafts.cancel(sessionID: session.id)
            uiState = .idle
        } catch {
            handleGenerationFailure(.emptyResponse)
        }
    }

    /// Resolve an insert tap: routes through the editor's callback.
    func insert(_ suggestion: AISuggestion, from session: AIDraftSession) {
        onInsert?(session, suggestion)
    }

    /// Callback when the editor's text changed mid-generation (race-avoidance).
    func editorChangedContent() {
        guard uiState == .loading || uiState == .ready else { return }
        // A newer edit invalidates the current context snapshot. Nudge the
        // sheet back to idle so the user can regenerate with fresh content.
        uiState = sessions.contains(where: { $0.state == .generating }) ? .loading : .idle
    }

    // MARK: - Private

    private func isTerminal(_ session: AIDraftSession) -> Bool {
        switch session.state {
        case .cancelled, .failed: return true
        case .idle, .generating, .ready: return false
        }
    }

    private func handleGenerationFailure(_ error: AIDraftError) {
        lastError = error
        uiState = error == .providerUnavailable ? .unavailable : .failed(error)
        sessions = []
    }
}