//
//  NotesRepository.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation

// MARK: - Protocol
protocol NotesRepository {
    func fetchAll() -> [Note]
    func fetch(id: UUID) -> Note?
    func save(_ note: Note)
    func delete(id: UUID)
    func deleteAll()
}

// MARK: - In-Memory Implementation (для тестів/прототипу)
final class InMemoryNotesRepository: NotesRepository {
    private var notes: [Note] = MockNotes

    func fetchAll() -> [Note] {
        return notes
    }

    func fetch(id: UUID) -> Note? {
        return notes.first { $0.id == id }
    }

    func save(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
    }

    func delete(id: UUID) {
        notes.removeAll { $0.id == id }
    }

    func deleteAll() {
        notes.removeAll()
    }
}

// MARK: - CoreData Implementation
//final class CoreDataNotesRepository: NotesRepository {
//    private let context: NSManagedObjectContext
//
//    init(context: NSManagedObjectContext) {
//        self.context = context
//    }
//
//    func fetchAll() -> [Note] {
//        let request = NoteEntity.fetchRequest()
//        do {
//            let entities = try context.fetch(request)
//            return entities.map { $0.toDomain() }
//        } catch {
//            print("CoreData fetch error: \(error)")
//            return []
//        }
//    }
//
//    func save(_ note: Note) {
//        let entity = NoteEntity(context: context)
//        entity.id = note.id
//        entity.title = note.title
//        entity.content = note.content
//        entity.createdAt = note.createdAt
//
//        do {
//            try context.save()
//        } catch {
//            print("CoreData save error: \(error)")
//        }
//    }
//
//    func delete(id: UUID) {
//        let request = NoteEntity.fetchRequest()
//        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
//
//        do {
//            let entities = try context.fetch(request)
//            entities.forEach { context.delete($0) }
//            try context.save()
//        } catch {
//            print("CoreData delete error: \(error)")
//        }
//    }
//
//    func fetch(id: UUID) -> Note? {
//        let request = NoteEntity.fetchRequest()
//        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
//        request.fetchLimit = 1
//
//        do {
//            return try context.fetch(request).first?.toDomain()
//        } catch {
//            return nil
//        }
//    }
//
//    func deleteAll() {
//        let request = NoteEntity.fetchRequest()
//        do {
//            let entities = try context.fetch(request)
//            entities.forEach { context.delete($0) }
//            try context.save()
//        } catch {
//            print("CoreData deleteAll error: \(error)")
//        }
//    }
//}

// MARK: - UserDefaults Implementation
final class UserDefaultsNotesRepository: NotesRepository {
    private let key = "saved_notes"
    private let defaults = UserDefaults.standard

    func fetchAll() -> [Note] {
        guard let data = defaults.data(forKey: key),
              let notes = try? JSONDecoder().decode([Note].self, from: data) else {
            return []
        }
        return notes
    }

    func save(_ note: Note) {
        var notes = fetchAll()
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }

        if let data = try? JSONEncoder().encode(notes) {
            defaults.set(data, forKey: key)
        }
    }

    func delete(id: UUID) {
        var notes = fetchAll()
        notes.removeAll { $0.id == id }

        if let data = try? JSONEncoder().encode(notes) {
            defaults.set(data, forKey: key)
        }
    }

    func fetch(id: UUID) -> Note? {
        return fetchAll().first { $0.id == id }
    }

    func deleteAll() {
        defaults.removeObject(forKey: key)
    }
}

// MARK: - API Implementation (async)
final class APINotesRepository: NotesRepository {
    private let baseURL = "https://api.example.com/notes"
    private var cachedNotes: [Note] = []

    func fetchAll() -> [Note] {
        // Повертає кешовані дані синхронно
        return cachedNotes
    }

    func fetchAllAsync() async throws -> [Note] {
        let url = URL(string: baseURL)!
        let (data, _) = try await URLSession.shared.data(from: url)
        let notes = try JSONDecoder().decode([Note].self, from: data)
        cachedNotes = notes
        return notes
    }

    func save(_ note: Note) {
        Task {
            try? await saveAsync(note)
        }
    }

    func saveAsync(_ note: Note) async throws {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(note)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        _ = try await URLSession.shared.data(for: request)

        // Оновити кеш
        if let index = cachedNotes.firstIndex(where: { $0.id == note.id }) {
            cachedNotes[index] = note
        } else {
            cachedNotes.append(note)
        }
    }

    func delete(id: UUID) {
        Task {
            try? await deleteAsync(id: id)
        }
    }

    func deleteAsync(id: UUID) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/\(id)")!)
        request.httpMethod = "DELETE"

        _ = try await URLSession.shared.data(for: request)
        cachedNotes.removeAll { $0.id == id }
    }

    func fetch(id: UUID) -> Note? {
        return cachedNotes.first { $0.id == id }
    }

    func deleteAll() {
        cachedNotes.removeAll()
    }
}
