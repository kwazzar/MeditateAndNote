//
//  TXTParser.swift
//  MeditateAndNoteCore
//

import Foundation

/// Parses plain-text books: blank-line-separated paragraphs in a single chapter.
public struct TXTParser: Sendable {
    public init() {}

    public func parse(_ data: Data, title: String?) -> BookContent {
        let raw = String(decoding: data, as: UTF8.self)
        let text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = text
            .components(separatedBy: "\n\n")
            .map { $0.split(whereSeparator: \.isNewline).joined(separator: " ").collapsedWhitespace() }
            .filter { !$0.isEmpty }
            .map { BookBlock(.paragraph, $0) }
        return BookContent(title: title, author: nil, chapters: [BookChapter(blocks: blocks)]).normalized()
    }
}
