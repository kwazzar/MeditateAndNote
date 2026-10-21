//
//  BookStore.swift
//  MeditateAndNoteCore
//

import Foundation

/// Persistence contract for books, their reading positions and covers.
///
/// Lives in the domain package rather than the app target on purpose: the
/// Android build compiles `MeditateAndNoteCore` and `MeditateAndNoteCoreJNI`
/// only, so a Swift adapter over a Room DAO has nowhere to live if the contract
/// sits in the app. `CoreDataBookStore` and `InMemoryBookStore` stay on the
/// Apple side as infrastructure.
public protocol BookStore: Sendable {
    func fetchAll() async throws -> [Book]
    func fetch(id: BookID) async throws -> Book?
    func save(_ book: Book) async throws
    func delete(id: BookID) async throws
    func deleteAll() async throws

    func readingPosition(for bookID: BookID) async throws -> ReadingPosition?
    func saveReadingPosition(_ position: ReadingPosition, for bookID: BookID) async throws

    func coverData(for bookID: BookID) async throws -> Data?
    func saveCoverData(_ data: Data?, for bookID: BookID) async throws
}
