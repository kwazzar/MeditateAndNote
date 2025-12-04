//
//  NotesRepository.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation

#warning("CoreData Implementation /Store")
typealias NotesRepository = Repository<Note, InMemoryNotesDataSource, CoreDataNotesDataSource>

//final class RepositoryFactory {
//    static func userRepository(source: DataSource) -> NotesDataSource {
//        switch source {
//        case .local:
//            return CoreDataUserRepository(context: container.viewContext)
//        case .remote:
//            return APIUserRepository(apiClient: apiClient)
//        case .hybrid:
//            return HybridUserRepository(local: CoreDataUserRepository(), remote: APIUserRepository())
//        }
//    }
//}

enum DataStrategy {
    case localOnly, remoteOnly, localFirst, remoteFirst, hybrid
}

protocol RepositoryProtocol {
    associatedtype Item

    func getItem(strategy: DataStrategy) async throws -> [Item]
    func getItem(id: String, strategy: DataStrategy) async throws -> Item
    func saveItem(_ note: Note, strategy: DataStrategy) async throws
    func deleteItem(id: String, strategy: DataStrategy) async throws
}

final class Repository<Item, LocalDS: DataSourceProtocol, RemoteDS: DataSourceProtocol>: RepositoryProtocol
where LocalDS.Item == Item, RemoteDS.Item == Item, Item: Identifiable, Item.ID == UUID {

    private let localDataSource: LocalDS
    private let remoteDataSource: RemoteDS

    init(localDataSource: LocalDS, remoteDataSource: RemoteDS) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
    }

    func getItems(strategy: DataStrategy) async throws -> [Item] {
        switch strategy {
        case .localOnly:
            return localDataSource.fetchAll()

        case .remoteOnly:
            return remoteDataSource.fetchAll()

        case .localFirst:
            let local = localDataSource.fetchAll()
            return local.isEmpty ? remoteDataSource.fetchAll() : local

        case .remoteFirst:
            let remote = remoteDataSource.fetchAll()
            return remote.isEmpty ? localDataSource.fetchAll() : remote

        case .hybrid:
            let local = localDataSource.fetchAll()
            let remote = remoteDataSource.fetchAll()

            // Merge, удаляя дубликаты по ID
            var merged = [UUID: Item]()
            (local + remote).forEach { merged[$0.id] = $0 }
            return Array(merged.values)
        }
    }

    func getItem(id: String, strategy: DataStrategy) async throws -> Item {
        guard let uuid = UUID(uuidString: id) else {
            throw RepositoryError.invalidID
        }

        switch strategy {
        case .localOnly:
            guard let item = localDataSource.fetch(id: uuid) else {
                throw RepositoryError.notFound
            }
            return item

        case .remoteOnly:
            guard let item = remoteDataSource.fetch(id: uuid) else {
                throw RepositoryError.notFound
            }
            return item

        case .localFirst:
            if let local = localDataSource.fetch(id: uuid) {
                return local
            }
            guard let remote = remoteDataSource.fetch(id: uuid) else {
                throw RepositoryError.notFound
            }
            return remote

        case .remoteFirst:
            if let remote = remoteDataSource.fetch(id: uuid) {
                return remote
            }
            guard let local = localDataSource.fetch(id: uuid) else {
                throw RepositoryError.notFound
            }
            return local

        case .hybrid:
            // Приоритет remote
            if let remote = remoteDataSource.fetch(id: uuid) {
                return remote
            }
            guard let local = localDataSource.fetch(id: uuid) else {
                throw RepositoryError.notFound
            }
            return local
        }
    }

    func saveItem(_ item: Item, strategy: DataStrategy) async throws {
        switch strategy {
        case .localOnly:
            localDataSource.save(item)

        case .remoteOnly:
            remoteDataSource.save(item)

        case .localFirst, .remoteFirst, .hybrid:
            // Сохраняем в оба источника
            localDataSource.save(item)
            remoteDataSource.save(item)
        }
    }

    func deleteItem(id: String, strategy: DataStrategy) async throws {
        guard let uuid = UUID(uuidString: id) else {
            throw RepositoryError.invalidID
        }

        switch strategy {
        case .localOnly:
            localDataSource.delete(id: uuid)

        case .remoteOnly:
            remoteDataSource.delete(id: uuid)

        case .localFirst, .remoteFirst, .hybrid:
            // Удаляем из обоих источников
            localDataSource.delete(id: uuid)
            remoteDataSource.delete(id: uuid)
        }
    }
}

// MARK: - Errors
enum RepositoryError: Error {
    case invalidID
    case notFound
    case saveFailed
}

// MARK: - NotesDataSource
protocol DataSourceProtocol {
    associatedtype Item

    func fetchAll() -> [Item]
    func fetch(id: UUID) -> Item?
    func save(_ note: Item)
    func delete(id: UUID)
    func deleteAll()
}

protocol NotesDataSource: DataSourceProtocol where Item == Note {}

// MARK: - In-Memory Implementation (для тестів/прототипу)
final class InMemoryNotesDataSource: NotesDataSource {
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
//final class CoreDataNotesDataSource: NotesRepository {
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
final class UserDefaultsNotesRepository: NotesDataSource {
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
final class APINotesRepository: NotesDataSource {
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
