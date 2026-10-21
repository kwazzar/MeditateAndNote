//
//  BookScope.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore

/// Owns the book reader stack: one manager + one store for the app lifetime.
final class BookScope: Sendable {
    let manager: BookManager

    init(store: any BookStore = CoreDataBookStore()) {
        self.manager = BookManager(store: store)
    }
}
