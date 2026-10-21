//
//  BookContent.swift
//  MeditateAndNoteCore
//

import Foundation

/// A single piece of text content inside a chapter.
public struct BookBlock: Hashable, Sendable {
    public enum Style: Hashable, Sendable {
        case heading
        case paragraph
    }

    public let style: Style
    public let text: String

    public init(_ style: Style, _ text: String) {
        self.style = style
        self.text = text
    }
}

public struct BookChapter: Hashable, Sendable {
    public var title: String?
    public let blocks: [BookBlock]

    public init(title: String? = nil, blocks: [BookBlock]) {
        self.title = title
        self.blocks = blocks
    }
}

/// Format-normalized book text produced by the parsers.
/// FB2, EPUB and TXT all end up here before pagination.
public struct BookContent: Hashable, Sendable {
    public let title: String?
    public let author: String?
    public let chapters: [BookChapter]

    public init(title: String? = nil, author: String? = nil, chapters: [BookChapter]) {
        self.title = title
        self.author = author
        self.chapters = chapters
    }

    /// Reading progress in [0, 1] for a logical position:
    /// characters consumed up to the position / total characters.
    public func progress(of position: ReadingPosition) -> Double {
        var consumed = 0
        let total = chapters.reduce(0) { $0 + $1.blocks.reduce(0) { $0 + $1.text.count } }
        guard total > 0 else { return 0 }
        for (index, chapter) in chapters.enumerated() {
            if index < position.chapterIndex {
                consumed += chapter.blocks.reduce(0) { $0 + $1.text.count }
            } else if index == position.chapterIndex {
                for (blockIndex, block) in chapter.blocks.enumerated() {
                    if blockIndex < position.blockIndex {
                        consumed += block.text.count
                    } else if blockIndex == position.blockIndex {
                        consumed += min(position.characterOffset, block.text.count)
                        break
                    }
                }
                break
            }
        }
        return Double(consumed) / Double(total)
    }

    /// Content with every block normalized (whitespace collapsed).
    public func normalized() -> BookContent {
        BookContent(
            title: title,
            author: author,
            chapters: chapters.map { chapter in
                BookChapter(
                    title: chapter.title?.collapsedWhitespace(),
                    blocks: chapter.blocks.compactMap { block in
                        let text = block.text.collapsedWhitespace()
                        guard !text.isEmpty else { return nil }
                        return BookBlock(block.style, text)
                    }
                )
            }
        )
    }
}

extension String {
    func collapsedWhitespace() -> String {
        split(whereSeparator: { $0.isNewline || $0.isWhitespace })
            .joined(separator: " ")
    }
}
