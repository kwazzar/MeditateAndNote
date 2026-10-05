//
//  NoteDataSource.swift
//  MeditateAndNoteCore
//

// MARK: - NoteDataSource (persistence boundary / ACL)

/// Persistence contract for notes.
///
/// Lives in the domain package rather than the app target on purpose: the
/// Android build compiles `MeditateAndNoteCore` and `MeditateAndNoteCoreJNI`
/// only, so a Swift adapter over a Room DAO has nowhere to live if the contract
/// sits in the app. `CoreDataNoteDataSource` and `InMemoryNoteDataSource` stay
/// on the Apple side as infrastructure.
public protocol NoteDataSource: Sendable {
    associatedtype Item where Item == Note

    func fetchAll() async throws -> [Note]
    func fetch(id: NoteID) async throws -> Note?
    func save(_ note: Note) async throws
    func delete(id: NoteID) async throws
    func deleteAll() async throws
}