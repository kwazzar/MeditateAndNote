//
//  BookmarkManager.swift
//  MeditateAndNote
//
//  Application Service: the reader's marks — page bookmarks and passage
//  highlights, the latter optionally turned into a note.
//

import Foundation
import MeditateAndNoteCore

// MARK: - Protocols for ViewModels

protocol BookmarkProvidable: Sendable {
    func bookmarks(for bookID: BookID) async throws -> [Bookmark]
    func bookmark(id: BookmarkID) async throws -> Bookmark?
}

protocol BookmarkManageable: Sendable {
    func add(_ bookmark: Bookmark) async throws
    func delete(id: BookmarkID) async throws
    func deleteAll(bookID: BookID) async throws
    /// Creates a highlight; with `asNote` it also writes a note holding the
    /// passage and links that note to the highlight.
    @discardableResult
    func createHighlight(
        bookID: BookID,
        position: ReadingPosition,
        text: String,
        bookTitle: String,
        location: String,
        asNote: Bool
    ) async throws -> Bookmark
}

// MARK: - Bookmark Manager (Application Service)

final actor BookmarkManager: BookmarkProvidable, BookmarkManageable {
    private let logger = Logger(subsystem: Config.bundleID, category: "BookmarkManager")
    private let store: any BookmarkStore
    private let noteWriter: (any NoteManageable)?

    init(store: any BookmarkStore, noteWriter: (any NoteManageable)? = nil) {
        self.store = store
        self.noteWriter = noteWriter
    }

    // MARK: - BookmarkProvidable

    func bookmarks(for bookID: BookID) async throws -> [Bookmark] {
        try await store.fetchAll(bookID: bookID)
    }

    func bookmark(id: BookmarkID) async throws -> Bookmark? {
        try await store.fetch(id: id)
    }

    // MARK: - BookmarkManageable

    func add(_ bookmark: Bookmark) async throws {
        try await store.save(bookmark)
    }

    func delete(id: BookmarkID) async throws {
        try await store.delete(id: id)
    }

    func deleteAll(bookID: BookID) async throws {
        try await store.deleteAll(bookID: bookID)
    }

    @discardableResult
    func createHighlight(
        bookID: BookID,
        position: ReadingPosition,
        text: String,
        bookTitle: String,
        location: String,
        asNote: Bool
    ) async throws -> Bookmark {
        var highlight = Bookmark.highlight(bookID, at: position, text: text)

        if asNote, let noteWriter {
            let note = Note(
                title: NoteTitle(bookTitle),
                content: NoteContent("\"\(text)\"\n\n— \(bookTitle), \(location)")
            )
            try await noteWriter.add(note)
            highlight.noteID = note.id
        }

        try await store.save(highlight)
        return highlight
    }
}
