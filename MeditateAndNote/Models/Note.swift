//
//  Note.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import Foundation

//MARK: - Value Types

struct NoteID: Hashable, Codable {
    let rawValue: UUID

    init() { self.rawValue = UUID() }
    init(rawValue: UUID) { self.rawValue = rawValue }

    static func == (lhs: NoteID, rhs: NoteID) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
    func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    // Codable
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uuid = try container.decode(UUID.self)
        self.init(rawValue: uuid)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}



//MARK: - NoteTitle

struct NoteTitle: Hashable, Codable {
    let rawValue: String

    init(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rawValue = trimmed.isEmpty ? "Untitled" : trimmed
    }
}

extension NoteTitle: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self.init(value) }
}

extension NoteTitle {
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

struct NoteContent: Hashable, Codable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension NoteContent: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self.init(value) }
}

extension NoteContent {
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

struct Note: Codable, Identifiable, Equatable {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case date
    }

    let id: NoteID
    let title: NoteTitle
    let content: NoteContent
    let date: Date

    init(id: NoteID = NoteID(), title: NoteTitle = NoteTitle(""), content: NoteContent = NoteContent(""), date: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
    }

    func updating(content: NoteContent) -> Note {
        Note(id: id, title: title, content: content, date: date)
    }

    func retitled(_ title: String) -> Note {
        Note(id: id, title: NoteTitle(title), content: content, date: date)
    }

    // Codable
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uuid = try container.decode(UUID.self, forKey: .id)
        self.id = NoteID(rawValue: uuid)
        let titleString = try container.decode(String.self, forKey: .title)
        self.title = NoteTitle(titleString)
        self.content = try container.decode(NoteContent.self, forKey: .content)
        self.date = try container.decode(Date.self, forKey: .date)
    }

    func encode(to encoder: Encoder) throws {
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
struct NoteBook {
    private var notesByID: [NoteID: Note]

    init(notes: [Note] = []) {
        self.notesByID = Dictionary(
            notes.map { ($0.id, $0) },
            uniquingKeysWith: Self.latest
        )
    }

    /// The newer of two versions of the same note.
    static func latest(_ current: Note, _ incoming: Note) -> Note {
        current.date >= incoming.date ? current : incoming
    }

    subscript(id: NoteID) -> Note? {
        notesByID[id]
    }

    var notes: [Note] {
        Array(notesByID.values)
    }

    mutating func upsert(_ note: Note) {
        let existing = notesByID[note.id]
        notesByID[note.id] = existing.map { Self.latest($0, note) } ?? note
    }

    mutating func remove(_ id: NoteID) {
        notesByID.removeValue(forKey: id)
    }
}

// MARK: - Merge Outcome (typed sync decision)

struct MergeConflict: Equatable {
    let id: NoteID
    let localVersion: Note
    let remoteVersion: Note
}

extension NoteBook {
    /// Hybrid-sync merge: per-ID last-write-wins, conflicts reported instead of hidden.
    static func merged(local: [Note], remote: [Note]) -> (notes: [Note], conflicts: [MergeConflict]) {
        var book = NoteBook(notes: local)
        var conflicts: [MergeConflict] = []

        for remoteNote in remote {
            if let localVersion = book[remoteNote.id], localVersion.date != remoteNote.date {
                conflicts.append(MergeConflict(id: remoteNote.id, localVersion: localVersion, remoteVersion: remoteNote))
            }
            book.upsert(remoteNote)
        }

        return (book.notes, conflicts)
    }
}
