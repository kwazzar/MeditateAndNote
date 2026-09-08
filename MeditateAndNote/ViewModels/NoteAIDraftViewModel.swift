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
    private let eventBus: DomainEventPublisher

    init(
        noteID: NoteID,
        currentContent: NoteContent,
        drafts: any AIDraftProvidable & AIDraftManageable,
        eventBus: DomainEventPublisher = DomainEventBus.shared
    ) {
        self.noteID = noteID
        self.currentContent = currentContent
        self.drafts = drafts
        self.eventBus = eventBus
    }

    /// Number of suggestions served in the current ready state, used to
    /// report per-suggestion rejection telemetry when the sheet closes.
    private var servedSuggestionCount = 0
    /// Set once a suggestion is inserted so dismissal after an insert isn't
    /// double-counted as a rejection.
    private var didInsert = false

    // MARK: - Actions

    /// Kicks off a generation. If a terminal session already exists for this
    /// note it is returned instead of spawning a duplicate.
    func start(instructions: String = "Give me ideas to continue this note") async {
        do {
            if let existing = try await drafts.session(for: noteID) {
                if existing.state == .ready {
                    presentReady(existing)
                    return
                }
            }

            uiState = .loading
            let session = try await drafts.startDraft(
                noteID: noteID,
                instructions: instructions,
                context: currentContent
            )
            present(session)
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
            present(refreshed)
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

    /// Resolve an insert tap: routes through the editor's callback and reports
    /// which suggestion the user picked.
    func insert(_ suggestion: AISuggestion, from session: AIDraftSession) {
        didInsert = true
        if let index = session.suggestions.firstIndex(where: { $0.id == suggestion.id }) {
            eventBus.publish(.aiDraftMetric(event: .suggestionInserted(index: index)))
        }
        onInsert?(session, suggestion)
    }

    /// Called when the sheet disappears: reports the remaining served
    /// suggestions as rejected when the user closes without inserting one.
    func sheetWillDismiss() {
        guard !didInsert else { return }
        guard servedSuggestionCount > 0 else { return }
        for index in 0..<servedSuggestionCount {
            eventBus.publish(.aiDraftMetric(event: .suggestionRejected(index: index)))
        }
    }

    /// Callback when the editor's text changed mid-generation (race-avoidance).
    func editorChangedContent() {
        guard uiState == .loading || uiState == .ready else { return }
        // A newer edit invalidates the current context snapshot. Nudge the
        // sheet back to idle so the user can regenerate with fresh content.
        uiState = sessions.contains(where: { $0.state == .generating }) ? .loading : .idle
    }

    // MARK: - Private

    private func present(_ session: AIDraftSession) {
        sessions = [session]
        uiState = session.state == .ready ? .ready : .failed(.noContext)
        if session.state == .ready {
            servedSuggestionCount = session.suggestions.count
        }
    }

    private func presentReady(_ session: AIDraftSession) {
        sessions = [session]
        uiState = .ready
        servedSuggestionCount = session.suggestions.count
    }

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