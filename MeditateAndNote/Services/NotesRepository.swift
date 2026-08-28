//
//  NotesRepository.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation
import OSLog

// MARK: - DataSource Protocol (Low-level storage)

protocol NoteDataSource {
    associatedtype Item where Item == Note

    func fetchAll() async throws -> [Note]
    func fetch(id: NoteID) async throws -> Note?
    func save(_ note: Note) async throws
    func delete(id: NoteID) async throws
    func deleteAll() async throws
}

// MARK: - In-Memory Implementation

final class InMemoryNoteDataSource: NoteDataSource {
    private var notes: [Note]

    /// Production starts empty; tests and previews seed explicitly.
    init(seedNotes: [Note] = []) {
        self.notes = seedNotes
    }

    func fetchAll() async throws -> [Note] {
        notes
    }

    func fetch(id: NoteID) async throws -> Note? {
        notes.first { $0.id == id }
    }

    func save(_ note: Note) async throws {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
    }

    func delete(id: NoteID) async throws {
        notes.removeAll { $0.id == id }
    }

    func deleteAll() async throws {
        notes.removeAll()
    }
}