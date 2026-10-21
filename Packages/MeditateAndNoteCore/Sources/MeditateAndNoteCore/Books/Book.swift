//
//  Book.swift
//  MeditateAndNoteCore
//

import Foundation

public struct BookID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init() { self.rawValue = UUID() }
    public init(rawValue: UUID) { self.rawValue = rawValue }

    public static func == (lhs: BookID, rhs: BookID) -> Bool {
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

public enum BookFormat: String, Codable, Sendable, CaseIterable {
    case fb2
    case epub
    case txt
}

public struct Book: Codable, Identifiable, Equatable, Sendable {
    public let id: BookID
    public var title: String
    public var author: String?
    public var format: BookFormat
    /// File name (not full path) of the stored book file, e.g. "<uuid>.fb2".
    public var fileName: String
    public var addedAt: Date
    public var lastOpenedAt: Date?

    public init(
        id: BookID = BookID(),
        title: String,
        author: String? = nil,
        format: BookFormat,
        fileName: String,
        addedAt: Date = Date(),
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.format = format
        self.fileName = fileName
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
    }
}

// MARK: - ReadingPosition

/// Logical reading position, independent of pagination/layout.
/// Re-pagination (font size, rotation) resolves through this, never by page number.
public struct ReadingPosition: Codable, Hashable, Sendable {
    public var chapterIndex: Int
    public var blockIndex: Int
    public var characterOffset: Int

    public init(chapterIndex: Int = 0, blockIndex: Int = 0, characterOffset: Int = 0) {
        self.chapterIndex = chapterIndex
        self.blockIndex = blockIndex
        self.characterOffset = characterOffset
    }

    /// Clamps to the first valid position at or after an invalid one
    /// (e.g. content shrank across app versions).
    public func clamped(to content: BookContent) -> ReadingPosition {
        var position = self
        position.chapterIndex = min(max(chapterIndex, 0), max(content.chapters.count - 1, 0))
        let blocks = content.chapters[position.chapterIndex].blocks
        position.blockIndex = min(max(blockIndex, 0), max(blocks.count - 1, 0))
        let text = blocks[position.blockIndex].text
        position.characterOffset = min(max(characterOffset, 0), max(text.count - 1, 0))
        return position
    }
}
