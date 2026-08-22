//
//  SearchQuery.swift
//  MeditateAndNote
//

import Foundation

struct SearchQuery {
    let text: String

    init(text: String) {
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum NoteFilter {
    static func matches(_ note: Note, query: SearchQuery) -> Bool {
        guard !query.text.isEmpty else { return true }
        return note.title.rawValue.localizedCaseInsensitiveContains(query.text)
            || note.content.localizedCaseInsensitiveContains(query.text)
    }
}
