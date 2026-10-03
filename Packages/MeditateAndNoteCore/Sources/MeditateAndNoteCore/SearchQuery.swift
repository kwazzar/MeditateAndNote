//
//  SearchQuery.swift
//  MeditateAndNote
//

import Foundation

/// Parsed search input. Emptiness is resolved once, at construction:
/// `.all` means "no filter", so callers never re-check for empty strings.
public enum SearchQuery: Equatable, Sendable {
    case all
    case term(String)

    public init(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self = trimmed.isEmpty ? .all : .term(trimmed)
    }

    /// Raw text of the query; empty when there is no term.
    public var text: String {
        if case let .term(text) = self { return text }
        return ""
    }
}

public enum NoteFilter: Sendable {
    public static func matches(_ note: Note, query: SearchQuery) -> Bool {
        switch query {
        case .all:
            return true
        case let .term(text):
            return note.title.rawValue.localizedCaseInsensitiveContains(text)
                || note.content.rawValue.localizedCaseInsensitiveContains(text)
        }
    }
}
