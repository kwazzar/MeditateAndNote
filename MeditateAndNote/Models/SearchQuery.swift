//
//  SearchQuery.swift
//  MeditateAndNote
//

import Foundation

/// Parsed search input. Emptiness is resolved once, at construction:
/// `.all` means "no filter", so callers never re-check for empty strings.
enum SearchQuery: Equatable {
    case all
    case term(String)

    init(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self = trimmed.isEmpty ? .all : .term(trimmed)
    }

    /// Raw text of the query; empty when there is no term.
    var text: String {
        if case let .term(text) = self { return text }
        return ""
    }
}

enum NoteFilter {
    static func matches(_ note: Note, query: SearchQuery) -> Bool {
        switch query {
        case .all:
            return true
        case let .term(text):
            return note.title.rawValue.localizedCaseInsensitiveContains(text)
                || note.content.rawValue.localizedCaseInsensitiveContains(text)
        }
    }
}
