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
    private let syncCoordinator: NoteSyncCoordinator
    private let noteId: NoteID?
    var isNewNote: Bool { noteId == nil }

    init(noteId: NoteID? = nil, noteRepository: NoteRepository, syncCoordinator: NoteSyncCoordinator) {
        self.noteRepository = noteRepository
        self.syncCoordinator = syncCoordinator
        self.noteId = noteId
        self.note = Note(title: MeditationTitle(""), content: "", date: Date())
        self.title = MeditationTitle("")
        self.content = ""

        if isNewNote {
            isEditing = true
        }
    }

    func loadNoteIfNeeded() async {
        guard let id = noteId, !isNewNote else { return }
        do {
            let existingNote = try await noteRepository.find(id)
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

        let updatedNote = Note(
            id: isNewNote ? NoteID() : note.id,
            title: title,
            content: content,
            date: isNewNote ? Date() : note.date
        )
        do {
            try await syncCoordinator.save(updatedNote, strategy: .hybrid)
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