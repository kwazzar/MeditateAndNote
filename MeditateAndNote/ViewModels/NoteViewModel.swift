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
    @Published var title: MeditationTitle = MeditationTitle("")
    @Published var content: String = ""
    @Published var errorText: String?
    @Published var isSaving: Bool = false
    
    private let noteRepository: NoteRepository
    private let noteId: UUID?
    private(set) var isNewNote: Bool
    
    init(noteId: UUID? = nil, noteRepository: NoteRepository) {
        self.noteRepository = noteRepository
        self.noteId = noteId
        
        if noteId != nil {
            self.note = Note(title: MeditationTitle(""), content: "", date: Date())
            self.title = MeditationTitle("")
            self.content = ""
            self.isNewNote = false
        } else {
            self.note = Note(title: MeditationTitle(""), content: "", date: Date())
            self.title = MeditationTitle("")
            self.content = ""
            self.isNewNote = true
            self.isEditing = true
        }
    }
    
    func loadNoteIfNeeded() async {
        guard let id = noteId, !isNewNote else { return }
        do {
            let existingNote = try await noteRepository.find(NoteID(rawValue: id))
            self.note = existingNote ?? Note(title: MeditationTitle(""), content: "", date: Date())
            self.title = existingNote?.title ?? MeditationTitle("")
            self.content = existingNote?.content ?? ""
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
            try await noteRepository.save(updatedNote)
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