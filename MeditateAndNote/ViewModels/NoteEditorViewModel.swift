//
//  NoteEditorViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 06.03.2025.
//

import Foundation
import Observation
import OSLog
import MeditateAndNoteCore

//MARK: - EditTarget (draft state machine)

enum EditTarget {
    case new
    case loading(id: NoteID)
    case loaded(id: NoteID, persisted: Note)
    case notFound(id: NoteID)
}

//MARK: - NoteEditorViewModel

@MainActor
@Observable
final class NoteEditorViewModel {
    private let logger = Logger(subsystem: Config.bundleID, category: "NoteEditorViewModel")

    var title: String = ""
    var body: String = ""

    private let notes: any NoteProvidable & NoteManageable
    private let drafts: any AIDraftProvidable & AIDraftManageable
    private let eventBus: DomainEventPublisher
    private var target: EditTarget
    private var autosaveTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    /// Internal AI draft view model, nil until the user first triggers generation.
    var aiDraftViewModel: NoteAIDraftViewModel?

    /// True when the inline AI suggestion bar should be visible.
    var showAIDraftBar: Bool {
        aiDraftViewModel != nil && (aiDraftViewModel?.uiState == .ready || aiDraftViewModel?.uiState == .loading)
    }

    /// True when AI is still generating suggestions.
    var isAIDraftLoading: Bool {
        aiDraftViewModel?.uiState == .loading
    }

    /// Pending suggestions not yet accepted.
    var pendingSuggestions: [AISuggestion] {
        guard let vm = aiDraftViewModel else { return [] }
        let acceptedIDs = Set(vm.acceptedSuggestions.map { $0.id })
        return vm.sessions.first?.suggestions.filter { !acceptedIDs.contains($0.id) } ?? []
    }

    /// Accepted suggestions waiting to be transferred.
    var acceptedSuggestions: [AISuggestion] {
        aiDraftViewModel?.acceptedSuggestions ?? []
    }

    var isNewNote: Bool {
        if case .new = target { return true }
        return false
    }

    /// The note's id when editing an existing note; nil for a fresh note.
    var currentNoteID: NoteID? {
        switch target {
        case .new, .loading:
            return nil
        case .loaded(let id, _), .notFound(let id):
            return id
        }
    }

    var isDirty: Bool {
        switch target {
        case .loading:
            return false
        case .new, .notFound:
            return !(title.isEmpty && body.isEmpty)
        case let .loaded(_, persisted):
            return persisted.title != NoteTitle(title) || persisted.content != NoteContent(body)
        }
    }

    /// An all-blank note is a mis-tap, never an intent — it must not be
    /// persisted (the list would fill with "Untitled" empties).
    var hasContent: Bool {
        !(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    init(noteId: NoteID? = nil,
         notes: any NoteProvidable & NoteManageable,
         drafts: any AIDraftProvidable & AIDraftManageable = AIDraftManagerStub(),
         eventBus: DomainEventPublisher = DomainEventBus.shared) {
        self.target = noteId.map(EditTarget.loading) ?? .new
        self.notes = notes
        self.drafts = drafts
        self.eventBus = eventBus

        if let noteId {
            loadTask = Task { [weak self] in
                guard let self else { return }
                await self.loadNote(noteId)
            }
        }
    }

    // MARK: - Load

    private func loadNote(_ id: NoteID) async {
        do {
            if let note = try await notes.note(with: id) {
                guard !Task.isCancelled else { return }
                title = note.title.rawValue
                body = note.content.rawValue
                target = .loaded(id: id, persisted: note)
            } else {
                target = .notFound(id: id)
            }
        } catch {
            logger.error("Failed to load note — \(error.localizedDescription)")
            target = .notFound(id: id)
        }
    }

    // MARK: - Autosave (debounced)

    func onTextChanged() {
        autosaveTask?.cancel()

        guard isDirty else { return }

        autosaveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled, self.isDirty else { return }
            await self.save()
        }
    }

    // MARK: - Save

    func save() async {
        switch target {
        case .loading:
            return

        case .new:
            guard hasContent else { return }
            await saveNewNote()

        case let .loaded(id, persisted):
            await saveExisting(id: id, persisted: persisted)

        case let .notFound(id):
            await saveExisting(id: id, persisted: nil)
        }
    }

    private func saveNewNote() async {
        let id = NoteID()
        let note = Note(id: id, title: NoteTitle(title), content: NoteContent(body), date: Date())
        title = note.title.rawValue

        do {
            try await notes.add(note)
            target = .loaded(id: id, persisted: note)
        } catch {
            logger.error("Save failed — \(error.localizedDescription)")
        }
    }

    private func saveExisting(id: NoteID, persisted: Note?) async {
        let date = persisted?.date ?? Date()
        let note = Note(id: id, title: NoteTitle(title), content: NoteContent(body), date: date)
        title = note.title.rawValue

        do {
            if let persisted, persisted == note {
                return
            }
            try await notes.update(note)
            target = .loaded(id: id, persisted: note)
        } catch {
            logger.error("Save failed — \(error.localizedDescription)")
        }
    }

    // MARK: - AI Draft (inline bottom bar)

    /// True when AI is currently generating suggestions.
    var isAIDraftGenerating: Bool {
        aiDraftViewModel?.uiState == .loading
    }

    /// Creates and starts the AI draft VM for this note, or re-runs the
    /// existing one against the current text. The old `nil` guard made ✨ a
    /// one-shot button: with nothing to accept there was no way back to a
    /// fresh generation. `NoteAIDraftViewModel.start` drops a session whose
    /// context no longer matches the note.
    func startAIDraft() async {
        if let vm = aiDraftViewModel {
            vm.updateContext(NoteContent(body))
            await vm.start()
            return
        }
        let noteID = currentNoteID ?? NoteID()
        let content = NoteContent(body)
        let vm = NoteAIDraftViewModel(
            noteID: noteID,
            currentContent: content,
            drafts: drafts,
            eventBus: eventBus
        )
        vm.onAcceptAll = { [weak self] proposals in
            self?.applyAcceptedProposals(proposals)
        }
        aiDraftViewModel = vm
        await vm.start()
    }

    /// Accept a suggestion.
    func acceptSuggestion(_ suggestion: AISuggestion) async {
        guard let vm = aiDraftViewModel else { return }
        let session = vm.sessions.first!
        await vm.accept(suggestion, from: session)
    }

    /// Reject an accepted suggestion back to pending.
    func rejectSuggestion(_ suggestion: AISuggestion) async {
        guard let vm = aiDraftViewModel else { return }
        let session = vm.sessions.first!
        await vm.reject(suggestion, from: session)
    }

    /// Accept all pending suggestions.
    func acceptAllSuggestions() async {
        guard let vm = aiDraftViewModel else { return }
        let session = vm.sessions.first!
        await vm.acceptAll(from: session)
    }

    /// Transfer all accepted suggestions into the note body.
    func transferAccepted() {
        guard let vm = aiDraftViewModel else { return }
        let session = vm.sessions.first!
        vm.transferAccepted(from: session)
        aiDraftViewModel = nil
    }

    /// Applies a single suggestion by appending it to the current note body.
    func applyDraft(_ content: NoteContent) {
        guard !content.rawValue.isEmpty else { return }
        let addition = content.rawValue.trimmingCharacters(in: .newlines)
        let existing = body.trimmingCharacters(in: .whitespacesAndNewlines)
        body = existing.isEmpty ? addition : body + "\n\n" + addition
        onTextChanged()
    }

    /// Transfers all accepted proposals into the note body.
    func applyAcceptedProposals(_ proposals: [AISuggestion]) {
        guard !proposals.isEmpty else { return }
        let texts = proposals.map { $0.text.trimmingCharacters(in: .newlines) }
        let addition = texts.joined(separator: "\n\n")
        let existing = body.trimmingCharacters(in: .whitespacesAndNewlines)
        body = existing.isEmpty ? addition : body + "\n\n" + addition
        onTextChanged()
    }

    // MARK: - Delete

    func delete() async {
        switch target {
        case .new:
            return
        case .loading:
            return
        case let .loaded(id, _):
            await performDelete(id)
        case let .notFound(id):
            await performDelete(id)
        }
    }

    private func performDelete(_ id: NoteID) async {
        do {
            try await notes.delete(with: id)
        } catch {
            logger.error("Delete failed — \(error.localizedDescription)")
        }
    }
}
