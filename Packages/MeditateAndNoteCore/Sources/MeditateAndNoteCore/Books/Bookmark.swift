//
//  Bookmark.swift
//  MeditateAndNoteCore
//

import Foundation

public struct BookmarkID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init() { self.rawValue = UUID() }
    public init(rawValue: UUID) { self.rawValue = rawValue }

    public static func == (lhs: BookmarkID, rhs: BookmarkID) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uuid = try container.decode(UUID.self)
        self.init(rawValue: uuid)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A mark the reader made in a book.
///
/// One aggregate covers both marks: a plain bookmark (no text) points at a
/// page, a highlight (with text) also remembers the marked passage and can
/// link to the note it was turned into.
public struct Bookmark: Codable, Identifiable, Equatable, Sendable {
    public let id: BookmarkID
    public let bookID: BookID
    /// Where in the book the mark sits. Page-independent: the reader resolves
    /// it against the current layout, so a font change keeps the mark on the
    /// same passage.
    public var position: ReadingPosition
    /// The marked passage; nil for a plain bookmark.
    public var text: String?
    /// The note this highlight was turned into, when it was.
    public var noteID: NoteID?
    public var createdAt: Date

    public init(
        id: BookmarkID = BookmarkID(),
        bookID: BookID,
        position: ReadingPosition,
        text: String? = nil,
        noteID: NoteID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.bookID = bookID
        self.position = position
        self.text = text
        self.noteID = noteID
        self.createdAt = createdAt
    }

    /// A plain page bookmark.
    public static func page(_ bookID: BookID, at position: ReadingPosition) -> Bookmark {
        Bookmark(bookID: bookID, position: position)
    }

    /// A highlight of a passage.
    public static func highlight(
        _ bookID: BookID,
        at position: ReadingPosition,
        text: String,
        noteID: NoteID? = nil
    ) -> Bookmark {
        Bookmark(bookID: bookID, position: position, text: text, noteID: noteID)
    }

    public var isHighlight: Bool { text != nil }
}
