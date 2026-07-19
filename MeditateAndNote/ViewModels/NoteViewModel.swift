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
    @Published var errorText: String?
    @Published var isSaving: Bool = false
    
    private let repository: NotesRepository
    private let noteId: UUID?
    private(set) var isNewNote: Bool
    
    init(noteId: UUID? = nil, repository: NotesRepository) {
        self.repository = repository
        self.noteId = noteId
        
        if noteId != nil {
            // Тимчасова заглушка, поки не завантажили реальну нотатку
            self.note = Note(title: "", content: "", date: Date())
            self.isNewNote = false
        } else {
            self.note = Note(title: "", content: "", date: Date())
            self.isNewNote = true
            self.isEditing = true
        }
    }
    
    func loadNoteIfNeeded() async {
        guard let id = noteId, !isNewNote else { return }
        do {
            let existingNote = try await repository.getItem(id: id.uuidString, strategy: .remoteFirst)
            self.note = existingNote
            self.title = existingNote.title
            self.content = existingNote.content
        } catch {
            errorText = "Не вдалося завантажити нотатку"
        }
    }
    
    func saveNote() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let updatedNote = Note(title: title, content: content, date: Date())
        do {
            try await repository.saveItem(updatedNote, strategy: .hybrid)
            note = updatedNote
            isEditing = false
        } catch {
            errorText = "Не вдалося зберегти нотатку"
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
