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
    func fetch(id: UUID) async throws -> Note?
    func save(_ note: Note) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
}

// MARK: - Errors

enum RepositoryError: Error {
    case invalidURL
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

// MARK: - Storage DTO (ACL between domain Note and persistence format)

private struct CodableNoteDTO: Codable {
    let id: UUID
    let title: String
    let content: String
    let date: Date
}

// MARK: - UserDefaults Implementation

final class UserDefaultsNoteDataSource: NoteDataSource {
    private static let key = "saved_notes"

    private let logger = Logger(subsystem: Config.bundleID, category: "NotesPersistence")
    private let defaults = UserDefaults.standard
    private var lastKnownGood: [Note]?

    private func decodeNotes(from data: Data) throws -> [Note] {
        let dtos = try JSONDecoder().decode([CodableNoteDTO].self, from: data)
        return dtos.map { dto in
            Note(
                id: NoteID(rawValue: dto.id),
                title: NoteTitle(dto.title),
                content: dto.content,
                date: dto.date
            )
        }
    }

    private func encodeNotes(_ notes: [Note]) -> Data? {
        let dtos = notes.map { note in
            CodableNoteDTO(id: note.id.rawValue, title: note.title.rawValue, content: note.content, date: note.date)
        }
        do {
            return try JSONEncoder().encode(dtos)
        } catch {
            logger.error("Failed to encode notes for storage — \(error.localizedDescription)")
            return nil
        }
    }

    func fetchAll() async throws -> [Note] {
        guard let data = defaults.data(forKey: Self.key) else { return lastKnownGood ?? [] }
        do {
            let notes = try decodeNotes(from: data)
            lastKnownGood = notes
            return notes
        } catch {
            logger.error("Failed to decode stored notes, keeping last known good state — \(error.localizedDescription)")
            return lastKnownGood ?? []
        }
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
        guard let data = encodeNotes(notes) else { throw RepositoryError.saveFailed }
        defaults.set(data, forKey: Self.key)
        lastKnownGood = notes
    }

    func delete(id: UUID) async throws {
        var notes = try await fetchAll()
        notes.removeAll { $0.id.rawValue == id }
        guard let data = encodeNotes(notes) else { throw RepositoryError.saveFailed }
        defaults.set(data, forKey: Self.key)
        lastKnownGood = notes
    }

    func deleteAll() async throws {
        defaults.removeObject(forKey: Self.key)
        lastKnownGood = []
    }
}

// MARK: - API Implementation

final class APINoteDataSource: NoteDataSource {
    private let baseURL = URL(string: "https://api.example.com/notes")
    private var cachedNotes: [Note] = []

    func fetchAll() async throws -> [Note] {
        cachedNotes
    }

    func fetch(id: UUID) async throws -> Note? {
        cachedNotes.first { $0.id.rawValue == id }
    }

    func save(_ note: Note) async throws {
        guard let url = baseURL else { throw RepositoryError.invalidURL }
        var request = URLRequest(url: url)
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
        guard let base = baseURL else { throw RepositoryError.invalidURL }
        var request = URLRequest(url: base.appendingPathComponent(id.uuidString))
        request.httpMethod = "DELETE"

        _ = try await URLSession.shared.data(for: request)
        cachedNotes.removeAll { $0.id.rawValue == id }
    }

    func deleteAll() async throws {
        cachedNotes.removeAll()
    }
}