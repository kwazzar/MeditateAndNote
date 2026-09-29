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
import OSLog

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

    /// True when the sheet opened with note text to work from. The sheet
    /// auto-starts generation in that case, so opening ✨ never requires
    /// typing — the prompt field is only for steering follow-ups (or for
    /// generating from a bare request on an empty note).
    var hasContext: Bool {
        !currentContent.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// False when the note was empty: the provider can only ask questions,
    /// so there is no text the user could accept into the note.
    var canAccept: Bool {
        sessions.first?.isGrounded ?? false
    }

    /// True while at least one suggestion is still pending. "Accept All" is
    /// idempotent, so it is a dead button once the pending pool is empty.
    var hasPending: Bool {
        guard let session = sessions.first else { return false }
        let acceptedIDs = Set(acceptedSuggestions.map(\.id))
        return session.suggestions.contains { !acceptedIDs.contains($0.id) }
    }

    /// True while there is something to move into the note. Deliberately
    /// independent of `hasPending`: after Accept All nothing is pending
    /// anymore, and tying the two together stranded every accepted
    /// suggestion behind a button that had just disappeared.
    var canTransfer: Bool {
        !acceptedSuggestions.isEmpty
    }

      /// Fired with the chosen suggestion when the user taps "Insert".
      @MainActor var onInsert: ((AIDraftSession, AISuggestion) -> Void)?
      /// Fired with all accepted suggestions when the user taps "Transfer to Note".
      @MainActor var onAcceptAll: (([AISuggestion]) -> Void)?

     /// Currently accepted suggestions from the active session.
     private(set) var acceptedSuggestions: [AISuggestion] = []

    // MARK: - Dependencies

    private let noteID: NoteID
    /// The editor's text as of the last push. Refreshed by `updateContext` on
    /// every generation — freezing it at init left a note that was empty on
    /// the first tap asking bare questions forever.
    private var currentContent: NoteContent
    private let drafts: any AIDraftProvidable & AIDraftManageable
    private let eventBus: DomainEventPublisher
    private let logger = Logger(subsystem: Config.bundleID, category: "AIDraftVM")

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

    /// Push the editor's current text in before generating. The prompt still
    /// takes its own frozen snapshot, so an in-flight generation is unaffected.
    func updateContext(_ content: NoteContent) {
        currentContent = content
    }

    /// Kicks off a generation. The default request depends on whether the note
    /// has text: with content the model continues it, without it the model
    /// asks questions. Every tap generates fresh — an earlier session is a
    /// frozen snapshot, and replaying it made ✨ look dead on a note that
    /// already had text. The old session is dropped so the note keeps exactly
    /// one.
    func start(instructions: String? = nil) async {
        let grounded = hasContext
        let request = instructions ?? (grounded
            ? "Give me ideas to continue this note"
            : "I have not written anything yet — ask me questions to start")
        do {
            if let existing = try await drafts.session(for: noteID), !existing.isInFlight {
                logger.info("Discarding previous session \(existing.id.uuidString) state=\(String(describing: existing.state)) grounded=\(existing.isGrounded) hasContext=\(grounded)")
                try await drafts.discardSessions(for: noteID)
            }

            uiState = .loading
            logger.info("Start draft grounded=\(grounded) request=\(request)")
            let session = try await drafts.startDraft(
                noteID: noteID,
                instructions: request,
                context: currentContent
            )
            logger.info("Session \(session.id.uuidString) state=\(String(describing: session.state)) suggestions=\(session.suggestions.count) canAccept=\(session.isGrounded)")
            present(session)
            lastError = nil
        } catch is CancellationError {
            uiState = .idle
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

    /// Accept a suggestion into the accepted pool via the manager and persist.
    func accept(_ suggestion: AISuggestion, from session: AIDraftSession) async {
        do {
            let updated = try await drafts.acceptSuggestion(sessionID: session.id, suggestionID: suggestion.id)
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = updated
            }
            acceptedSuggestions = updated.acceptedSuggestions
        } catch {
            lastError = error as? AIDraftError ?? .emptyResponse
        }
    }

    /// Reject an accepted suggestion back to pending via the manager and persist.
    func reject(_ suggestion: AISuggestion, from session: AIDraftSession) async {
        do {
            let updated = try await drafts.rejectSuggestion(sessionID: session.id, suggestionID: suggestion.id)
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = updated
            }
            acceptedSuggestions = updated.acceptedSuggestions
        } catch {
            lastError = error as? AIDraftError ?? .emptyResponse
        }
    }

    /// Accept all pending suggestions via the manager and persist.
    func acceptAll(from session: AIDraftSession) async {
        do {
            let updated = try await drafts.acceptAllSuggestions(sessionID: session.id)
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = updated
            }
            acceptedSuggestions = updated.acceptedSuggestions
        } catch {
            lastError = error as? AIDraftError ?? .emptyResponse
        }
    }

    /// Transfer all accepted suggestions to the note via the callback.
    func transferAccepted(from session: AIDraftSession) {
        guard !acceptedSuggestions.isEmpty else { return }
        onAcceptAll?(acceptedSuggestions)
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
        // A fresh generation replaces the accepted pool — keeping the old ids
        // would leave Transfer counting suggestions that are no longer shown.
        acceptedSuggestions = []
        uiState = session.state == .ready ? .ready : .failed(.noContext)
        if session.state == .ready {
            servedSuggestionCount = session.suggestions.count
        }
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