//
//  Note.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import Foundation

//MARK: - Value Types

public struct NoteID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init() { self.rawValue = UUID() }
    public init(rawValue: UUID) { self.rawValue = rawValue }

    public static func == (lhs: NoteID, rhs: NoteID) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    // Codable
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



//MARK: - NoteTitle

public struct NoteTitle: Hashable, Codable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rawValue = trimmed.isEmpty ? "Untitled" : trimmed
    }
}

extension NoteTitle: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self.init(value) }
}

public extension NoteTitle {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.init(value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

//MARK: - NoteContent

public struct NoteContent: Hashable, Codable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension NoteContent: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self.init(value) }
}

public extension NoteContent {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

//MARK: - Note

public struct Note: Codable, Identifiable, Equatable, Sendable {
    public enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case date
    }

    public let id: NoteID
    public let title: NoteTitle
    public let content: NoteContent
    public let date: Date

    public init(id: NoteID = NoteID(), title: NoteTitle = NoteTitle(""), content: NoteContent = NoteContent(""), date: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
    }

    public func updating(content: NoteContent) -> Note {
        Note(id: id, title: title, content: content, date: date)
    }

    public func retitled(_ title: String) -> Note {
        Note(id: id, title: NoteTitle(title), content: content, date: date)
    }

    // Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uuid = try container.decode(UUID.self, forKey: .id)
        self.id = NoteID(rawValue: uuid)
        let titleString = try container.decode(String.self, forKey: .title)
        self.title = NoteTitle(titleString)
        self.content = try container.decode(NoteContent.self, forKey: .content)
        self.date = try container.decode(Date.self, forKey: .date)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.rawValue, forKey: .id)
        try container.encode(title.rawValue, forKey: .title)
        try container.encode(content.rawValue, forKey: .content)
        try container.encode(date, forKey: .date)
    }
}

//MARK: - NoteBook (aggregate over the note collection)

/// Owns collection-level invariants: one entry per NoteID,
/// last-write-wins resolution by date.
public struct NoteBook {
    private var notesByID: [NoteID: Note]

    public init(notes: [Note] = []) {
        self.notesByID = Dictionary(
            notes.map { ($0.id, $0) },
            uniquingKeysWith: Self.latest
        )
    }

    /// The newer of two versions of the same note.
    public static func latest(_ current: Note, _ incoming: Note) -> Note {
        current.date >= incoming.date ? current : incoming
    }

    public subscript(id: NoteID) -> Note? {
        notesByID[id]
    }

    public var notes: [Note] {
        Array(notesByID.values)
    }

    public mutating func upsert(_ note: Note) {
        let existing = notesByID[note.id]
        notesByID[note.id] = existing.map { Self.latest($0, note) } ?? note
    }

    public mutating func remove(_ id: NoteID) {
        notesByID.removeValue(forKey: id)
    }
}
