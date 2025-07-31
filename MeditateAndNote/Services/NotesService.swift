//
//  NotesService.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation

final class NotesService: ObservableObject {
    @Published var notes: [Note] = MockNotes

    func fetchNotes() -> [Note] {
        return notes
    }

    func saveNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
    }

    func getNote(id: UUID) -> Note? {
        return notes.first { $0.id == id }
    }
}
