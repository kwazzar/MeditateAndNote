//
//  BookScope.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore

/// Owns the book reader stack: one manager + one store for the app lifetime.
final class BookScope: Sendable {
    let manager: BookManager
    let bookmarkManager: BookmarkManager

    init(
        store: any BookStore = CoreDataBookStore(),
        bookmarkStore: any BookmarkStore = CoreDataBookmarkStore(),
        fileStorage: BookFileStorage = BookFileStorage(),
        noteWriter: (any NoteManageable)? = nil
    ) {
        self.manager = BookManager(store: store, fileStorage: fileStorage)
        self.bookmarkManager = BookmarkManager(store: bookmarkStore, noteWriter: noteWriter)
    }
}
