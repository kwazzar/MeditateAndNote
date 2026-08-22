//
//  NoteViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 03.03.2025.
//

import SwiftUI

//MARK: - NoteViewModel

final class NoteViewModel: ObservableObject {

    // MARK: - State machine

    enum LoadState {
        case new
        case loading(id: NoteID)
        case loaded(persisted: Note)
        case notFound(id: NoteID)
    }

    // MARK: - Published state

    @Published private(set) var state: LoadState = .new
    @Published var isEditing: Bool = false
    @Published var title: NoteTitle = NoteTitle("")
    @Published var content: NoteContent = NoteContent("")
    @Published var error: NoteOperationError?
    @Published var isSaving: Bool = false

    private let notes: any NoteProvidable & NoteManageable

    init(noteId: NoteID? = nil, notes: any NoteProvidable & NoteManageable) {
        self.notes = notes
        guard let id = noteId else {
            state = .new
            isEditing = true
            return
        }
        state = .loading(id: id)
        Task { await loadNote(id) }
    }

    // MARK: - Derived state

    var isNewNote: Bool {
        if case .new = state { return true }
        return false
    }

    /// The persisted note, present only in the `.loaded` state.
    /// A "new" note is no longer modelled as a fake entity.
    var note: Note? {
        if case let .loaded(persisted) = state { return persisted }
        return nil
    }

    // MARK: - Load

    func loadNoteIfNeeded() async {
        guard case let .loading(id) = state else { return }
        await loadNote(id)
    }

    private func loadNote(_ id: NoteID) async {
        do {
            if let existing = try await notes.note(with: id) {
                state = .loaded(persisted: existing)
                title = existing.title
                content = existing.content
            } else {
                state = .notFound(id: id)
            }
        } catch {
            self.error = .loadFailed(id)
        }
    }

    // MARK: - Save

    func saveNote() async {
        guard !isSaving else { return }
        switch state {
        case .new:
            await createNewNote()

        case .loading:
            break

        case let .loaded(persisted):
            await updateExisting(persisted)

        case let .notFound(id):
            await recreateDeleted(id: id)
        }
    }

    private func createNewNote() async {
        isSaving = true
        defer { isSaving = false }

        let newNote = Note(title: title, content: content, date: Date())
        do {
            try await notes.add(newNote)
            state = .loaded(persisted: newNote)
            isEditing = false
        } catch {
            self.error = .saveFailed
        }
    }

    private func updateExisting(_ persisted: Note) async {
        let updated = Note(id: persisted.id, title: title, content: content, date: persisted.date)
        guard updated != persisted else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await notes.update(updated)
            state = .loaded(persisted: updated)
            isEditing = false
        } catch {
            self.error = .saveFailed
        }
    }

    private func recreateDeleted(id: NoteID) async {
        isSaving = true
        defer { isSaving = false }

        let restored = Note(id: id, title: title, content: content, date: Date())
        do {
            try await notes.add(restored)
            state = .loaded(persisted: restored)
            isEditing = false
        } catch {
            self.error = .saveFailed
        }
    }

    // MARK: - Editing controls

    func startEditing() {
        isEditing = true
    }

    func cancelEditing() {
        switch state {
        case let .loaded(persisted):
            title = persisted.title
            content = persisted.content
        case .new, .loading, .notFound:
            title = NoteTitle("")
            content = NoteContent("")
        }
        isEditing = false
    }
}
