//
//  NoteEditorViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 06.03.2025.
//

import Foundation
import Observation
import OSLog

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
    private var target: EditTarget
    private var autosaveTask: Task<Void, Never>?

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

    init(noteId: NoteID? = nil,
         notes: any NoteProvidable & NoteManageable) {
        self.target = noteId.map(EditTarget.loading) ?? .new
        self.notes = notes

        if let noteId {
            Task { await loadNote(noteId) }
        }
    }

    // MARK: - Load

    private func loadNote(_ id: NoteID) async {
        do {
            if let note = try await notes.note(with: id) {
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

    // MARK: - AI Draft Integration

    /// Applies a suggestion picked from the AI sheet, then nudges autosave.
    func applyDraft(_ content: NoteContent) {
        guard !content.rawValue.isEmpty else { return }
        body = content.rawValue
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
