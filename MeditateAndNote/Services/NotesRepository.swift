//
//  NotesRepository.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation

// MARK: - Repository Protocol (Pure CRUD, no sync strategy)

protocol NoteRepository {
    func all() async throws -> [Note]
    func find(_ id: NoteID) async throws -> Note?
    func save(_ note: Note) async throws
    func delete(_ id: NoteID) async throws
}

// MARK: - DataSource Protocol (Low-level storage)

protocol NoteDataSource {
    associatedtype Item where Item == Note
    
    func fetchAll() async throws -> [Note]
    func fetch(id: UUID) async throws -> Note?
    func save(_ note: Note) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
}

// MARK: - Concrete Repository Implementation

final class DefaultNoteRepository: NoteRepository {
    private let dataSource: any NoteDataSource
    
    init(dataSource: any NoteDataSource) {
        self.dataSource = dataSource
    }
    
    func all() async throws -> [Note] {
        try await dataSource.fetchAll()
    }
    
    func find(_ id: NoteID) async throws -> Note? {
        try await dataSource.fetch(id: id.rawValue)
    }
    
    func save(_ note: Note) async throws {
        try await dataSource.save(note)
    }
    
    func delete(_ id: NoteID) async throws {
        try await dataSource.delete(id: id.rawValue)
    }
}

// MARK: - Errors

enum RepositoryError: Error {
    case invalidID
    case notFound
    case saveFailed
}

// MARK: - In-Memory Implementation

final class InMemoryNoteDataSource: NoteDataSource {
    private var notes: [Note] = MockNotes
    
    func fetchAll() async throws -> [Note] {
        notes
    }
    
    func fetch(id: UUID) async throws -> Note? {
        notes.first { $0.id.rawValue == id }
    }
    
    func save(_ note: Note) async throws {
        if let index = notes.firstIndex(where: { $0.id.rawValue == note.id.rawValue }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
    }
    
    func delete(id: UUID) async throws {
        notes.removeAll { $0.id.rawValue == id }
    }
    
    func deleteAll() async throws {
        notes.removeAll()
    }
}

// MARK: - UserDefaults Implementation

final class UserDefaultsNoteDataSource: NoteDataSource {
    private let key = "saved_notes"
    private let defaults = UserDefaults.standard
    
    func fetchAll() async throws -> [Note] {
        guard let data = defaults.data(forKey: key),
              let notes = try? JSONDecoder().decode([Note].self, from: data) else {
            return []
        }
        return notes
    }
    
    func fetch(id: UUID) async throws -> Note? {
        try await fetchAll().first { $0.id.rawValue == id }
    }
    
    func save(_ note: Note) async throws {
        var notes = try await fetchAll()
        if let index = notes.firstIndex(where: { $0.id.rawValue == note.id.rawValue }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
        if let data = try? JSONEncoder().encode(notes) {
            defaults.set(data, forKey: key)
        }
    }
    
    func delete(id: UUID) async throws {
        var notes = try await fetchAll()
        notes.removeAll { $0.id.rawValue == id }
        if let data = try? JSONEncoder().encode(notes) {
            defaults.set(data, forKey: key)
        }
    }
    
    func deleteAll() async throws {
        defaults.removeObject(forKey: key)
    }
}

// MARK: - API Implementation

final class APINoteDataSource: NoteDataSource {
    private let baseURL = "https://api.example.com/notes"
    private var cachedNotes: [Note] = []
    
    func fetchAll() async throws -> [Note] {
        cachedNotes
    }
    
    func fetch(id: UUID) async throws -> Note? {
        cachedNotes.first { $0.id.rawValue == id }
    }
    
    func save(_ note: Note) async throws {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(note)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        _ = try await URLSession.shared.data(for: request)
        
        if let index = cachedNotes.firstIndex(where: { $0.id.rawValue == note.id.rawValue }) {
            cachedNotes[index] = note
        } else {
            cachedNotes.append(note)
        }
    }
    
    func delete(id: UUID) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/\(id)")!)
        request.httpMethod = "DELETE"
        
        _ = try await URLSession.shared.data(for: request)
        cachedNotes.removeAll { $0.id.rawValue == id }
    }
    
    func deleteAll() async throws {
        cachedNotes.removeAll()
    }
}