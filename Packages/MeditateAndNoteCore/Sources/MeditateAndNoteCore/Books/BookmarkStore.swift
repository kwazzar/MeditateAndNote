//
//  BookmarkStore.swift
//  MeditateAndNoteCore
//

import Foundation

/// Persistence contract for the reader's marks (bookmarks and highlights).
///
/// Lives in the domain package rather than the app target on purpose: the
/// Android build compiles `MeditateAndNoteCore` and `MeditateAndNoteCoreJNI`
/// only, so a Swift adapter over a Room DAO has nowhere to live if the contract
/// sits in the app. `CoreDataBookmarkStore` and `InMemoryBookmarkStore` stay
/// on the Apple side as infrastructure.
public protocol BookmarkStore: Sendable {
    func fetchAll(bookID: BookID) async throws -> [Bookmark]
    func fetch(id: BookmarkID) async throws -> Bookmark?
    func save(_ bookmark: Bookmark) async throws
    func delete(id: BookmarkID) async throws
    func deleteAll(bookID: BookID) async throws
}
