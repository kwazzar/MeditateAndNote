//
//  CoreDataAIDraftSessionStore.swift
//  MeditateAndNote
//
//  Core Data implementation of AIDraftSessionStore. The aggregate is stored as
//  JSON blobs for the value-type sub-parts (prompt, suggestions, state), with
//  indexed scalar attributes for querying. NSManagedObject never leaks here.
//

import CoreData
import Foundation
import OSLog

final class CoreDataAIDraftSessionStore: AIDraftSessionStore {

    private let logger = Logger(subsystem: Config.bundleID, category: "CoreDataAIDraft")
    nonisolated(unsafe) private let manager: CoreDataManager

    init(manager: CoreDataManager = .shared) {
        self.manager = manager
    }

    func fetchAll() async throws -> [AIDraftSession] {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.aiDraftSession)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            let results = try context.fetch(request)
            return results.compactMap(Self.toSession)
        }
    }

    func fetch(id: UUID) async throws -> AIDraftSession? {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.aiDraftSession)
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            return try context.fetch(request).first.flatMap(Self.toSession)
        }
    }

    func fetch(noteID: NoteID) async throws -> AIDraftSession? {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.aiDraftSession)
            request.predicate = NSPredicate(format: "noteID == %@", noteID.rawValue as CVarArg)
            request.fetchLimit = 1

            return try context.fetch(request).first.flatMap(Self.toSession)
        }
    }

    func save(_ session: AIDraftSession) async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let object = Self.findOrCreate(id: session.id, in: context)
            Self.apply(session, to: object)
            try context.save()
        }
    }

    func delete(id: UUID) async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.aiDraftSession)
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            if let object = try context.fetch(request).first {
                context.delete(object)
                try context.save()
            }
        }
    }

    func delete(noteID: NoteID) async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.aiDraftSession)
            request.predicate = NSPredicate(format: "noteID == %@", noteID.rawValue as CVarArg)

            for object in try context.fetch(request) {
                context.delete(object)
            }
            try context.save()
        }
    }

    func deleteAll() async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.aiDraftSession)
            for object in try context.fetch(request) {
                context.delete(object)
            }
            try context.save()
        }
    }

    // MARK: - Mapping Helpers

    private static func toSession(_ object: NSManagedObject) -> AIDraftSession? {
        guard let id = object.value(forKey: "id") as? UUID,
              let noteID = object.value(forKey: "noteID") as? UUID,
              let promptData = object.value(forKey: "promptJSON") as? Data,
              let suggestionsData = object.value(forKey: "suggestionsJSON") as? Data,
              let stateRaw = object.value(forKey: "stateRaw") as? String,
              let createdAt = object.value(forKey: "createdAt") as? Date,
              let prompt = try? JSONDecoder().decode(AIPrompt.self, from: promptData),
              let suggestions = try? JSONDecoder().decode([AISuggestion].self, from: suggestionsData),
              let state = decodeState(stateRaw) else {
            return nil
        }
        return AIDraftSession(
            id: id,
            noteID: NoteID(rawValue: noteID),
            prompt: prompt,
            suggestions: suggestions,
            state: state,
            createdAt: createdAt
        )
    }

    private static func apply(_ session: AIDraftSession, to object: NSManagedObject) {
        object.setValue(session.id, forKey: "id")
        object.setValue(session.noteID.rawValue, forKey: "noteID")
        object.setValue(try? JSONEncoder().encode(session.prompt), forKey: "promptJSON")
        object.setValue(try? JSONEncoder().encode(session.suggestions), forKey: "suggestionsJSON")
        object.setValue(encodeState(session.state), forKey: "stateRaw")
        object.setValue(session.createdAt, forKey: "createdAt")
    }

    private static func findOrCreate(id: UUID, in context: NSManagedObjectContext) -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.aiDraftSession)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: CDEntity.aiDraftSession, into: context)
    }

    // MARK: - State (de)serialization
    // AIDraftState carries an associated AIDraftError for .failed; encode the
    // case + raw error string so the row stays round-trippable.

    private static func encodeState(_ state: AIDraftState) -> String {
        switch state {
        case .idle: return "idle"
        case .generating: return "generating"
        case .ready: return "ready"
        case .failed(let error): return "failed:\(error.rawValue)"
        case .cancelled: return "cancelled"
        }
    }

    private static func decodeState(_ raw: String) -> AIDraftState? {
        if raw == "idle" { return .idle }
        if raw == "generating" { return .generating }
        if raw == "ready" { return .ready }
        if raw == "cancelled" { return .cancelled }
        if raw.hasPrefix("failed:") {
            let code = raw.dropFirst("failed:".count)
            if let error = AIDraftError(rawValue: String(code)) {
                return .failed(error)
            }
        }
        return nil
    }
}
