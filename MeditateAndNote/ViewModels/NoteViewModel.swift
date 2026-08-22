//
//  NoteViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 03.03.2025.
//

import SwiftUI

final class NoteViewModel: ObservableObject {
    @Published var note: Note
    @Published var isEditing: Bool = false
    @Published var title: NoteTitle = NoteTitle("")
    @Published var content: String = ""
    @Published var error: NoteOperationError?
    @Published var isSaving: Bool = false

    private let notes: any NoteProvidable & NoteManagable
    private let noteId: NoteID?
    var isNewNote: Bool { noteId == nil }

    init(noteId: NoteID? = nil, notes: any NoteProvidable & NoteManagable) {
        self.notes = notes
        self.noteId = noteId
        self.note = Note(title: NoteTitle(""), content: "", date: Date())
        self.title = NoteTitle("")
        self.content = ""

        if isNewNote {
            isEditing = true
        }
    }

    func loadNoteIfNeeded() async {
        guard let id = noteId, !isNewNote else { return }
        do {
            let existingNote = try await notes.note(with: id)
            self.note = existingNote ?? Note(title: NoteTitle(""), content: "", date: Date())
            self.title = existingNote?.title ?? NoteTitle("")
            self.content = existingNote?.content ?? ""
        } catch {
            self.error = .loadFailed(id)
        }
    }

    func saveNote() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let updatedNote = Note(
            id: isNewNote ? NoteID() : note.id,
            title: title,
            content: content,
            date: isNewNote ? Date() : note.date
        )
        do {
            if isNewNote {
                try await notes.add(updatedNote)
            } else {
                try await notes.update(updatedNote)
            }
            note = updatedNote
            isEditing = false
        } catch {
            self.error = .saveFailed
        }
    }

    func startEditing() {
        isEditing = true
    }

    func cancelEditing() {
        title = note.title
        content = note.content
        isEditing = false
    }
}
