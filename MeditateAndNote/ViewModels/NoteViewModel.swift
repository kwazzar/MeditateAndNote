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
    @Published var title: String = ""
    @Published var content: String = ""

    private let repository: NotesRepository
    private let isNewNote: Bool

    init(noteId: UUID? = nil, repository: NotesRepository) {
        self.repository = repository

        #warning("UUID Search")
        if let id = noteId, let existingNote = repository.fetch(id: id) {
            self.note = existingNote
            self.isNewNote = false
            self.title = existingNote.title
            self.content = existingNote.content
        } else {
            self.note = Note(title: "", content: "", date: Date())
            self.isNewNote = true
            self.isEditing = true
        }
    }

    func saveNote() {
        let updatedNote = Note(title: title, content: content, date: Date())
        repository.save(updatedNote)
        note = updatedNote
        isEditing = false
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

extension NoteViewModel {
    func set(note: Note) {
        self.note = note
        self.title = note.title
        self.content = note.content
        self.isEditing = false
    }
}
