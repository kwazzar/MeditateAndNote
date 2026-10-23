//
//  FB2Parser.swift
//  MeditateAndNoteCore
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Parses FictionBook 2 (FB2) XML into `BookContent`.
/// Extracts title, author, cover image reference; text only (no inline images).
public struct FB2Parser: Sendable {
    public init() {}

    public struct ParseResult: Sendable {
        public let content: BookContent
        public let coverData: Data?
    }

    public func parse(_ data: Data) throws -> ParseResult {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), let content = delegate.content() else {
            throw BookParseError.invalidFormat(parser.parserError?.localizedDescription ?? "no content")
        }
        let coverData = delegate.coverHref
            .flatMap { href in delegate.binaries[href.trimmingCharacters(in: CharacterSet(charactersIn: "#"))] }
            .flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }
        return ParseResult(content: content.normalized(), coverData: coverData)
    }
}

public enum BookParseError: Error, Sendable {
    case invalidFormat(String)
}

private final class Delegate: NSObject, XMLParserDelegate {
    var title: String?
    var authorParts: [String] = []
    var coverHref: String?
    var binaries: [String: String] = [:]

    /// FB2 carries the translation title in `title-info` and the original
    /// language title in `src-title-info`. The first one is the book's title;
    /// the second would otherwise overwrite it.
    private var didCaptureTitle = false
    private var didCaptureAuthor = false

    private var elementStack: [String] = []
    private var chapters: [BookChapter] = []
    private var currentChapter: BookChapter?
    private var currentBlocks: [BookBlock] = []
    private var buffer = ""
    private var captureTarget: CaptureTarget?
    private var currentBinaryID: String?

    private enum CaptureTarget {
        case bookTitle
        case authorName
        case binary
    }

    func content() -> BookContent? {
        if let currentChapter, currentChapter.title != nil || !currentBlocks.isEmpty {
            chapters.append(finishChapter(currentChapter, blocks: currentBlocks))
        }
        if chapters.isEmpty { return nil }
        let author = authorParts.isEmpty ? nil : authorParts.joined(separator: " ")
        return BookContent(title: title, author: author, chapters: chapters)
    }

    private func finishChapter(_ chapter: BookChapter, blocks: [BookBlock]) -> BookChapter {
        BookChapter(title: chapter.title?.collapsedWhitespace(), blocks: blocks)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = localName(elementName)
        elementStack.append(name)

        switch name {
        case "author":
            break
        case "first-name", "last-name":
            buffer = ""
            if !didCaptureAuthor, elementStack.contains("author") {
                captureTarget = .authorName
            }
        case "book-title":
            buffer = ""
            captureTarget = .bookTitle
        case "coverpage":
            break
        case "image":
            if elementStack.contains("coverpage"), let href = attributeDict.first(where: { localName($0.key) == "href" })?.value {
                coverHref = href
            }
        case "binary":
            buffer = ""
            currentBinaryID = attributeDict["id"]
            captureTarget = .binary
        case "body":
            if let chapter = currentChapter, chapter.title != nil || !currentBlocks.isEmpty {
                chapters.append(finishChapter(chapter, blocks: currentBlocks))
            }
            currentChapter = BookChapter(title: nil, blocks: [])
            currentBlocks = []
        case "section":
            // Every section is a chapter; nested sections become their own chapters.
            if let chapter = currentChapter, chapter.title != nil || !currentBlocks.isEmpty {
                chapters.append(finishChapter(chapter, blocks: currentBlocks))
            }
            currentChapter = BookChapter(title: nil, blocks: [])
            currentBlocks = []
        case "p":
            buffer = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = localName(elementName)
        elementStack.removeLast()

        switch name {
        case "author":
            didCaptureAuthor = true
        case "book-title":
            if captureTarget == .bookTitle {
                if !didCaptureTitle {
                    title = buffer.collapsedWhitespace()
                    didCaptureTitle = true
                }
                captureTarget = nil
            }
        case "first-name", "last-name":
            if captureTarget == .authorName {
                authorParts.append(buffer.collapsedWhitespace())
                captureTarget = nil
            }
        case "binary":
            if let id = currentBinaryID {
                binaries[id] = buffer
                currentBinaryID = nil
            }
            captureTarget = nil
        case "p":
            let text = buffer.collapsedWhitespace()
            buffer = ""
            guard !text.isEmpty else { return }
            let inSectionTitle = isInsideSectionTitle()
            let style: BookBlock.Style = inSectionTitle ? .heading : .paragraph
            if inSectionTitle, currentChapter?.title == nil, currentBlocks.isEmpty, style == .heading {
                currentChapter?.title = text
            } else {
                currentBlocks.append(BookBlock(style, text))
            }
        case "body":
            if let chapter = currentChapter, chapter.title != nil || !currentBlocks.isEmpty {
                chapters.append(finishChapter(chapter, blocks: currentBlocks))
            }
            currentChapter = nil
            currentBlocks = []
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard captureTarget != nil || isInsideParagraph() else { return }
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard isInsideParagraph() || captureTarget != nil else { return }
        if let text = String(data: CDATABlock, encoding: .utf8) {
            buffer += text
        }
    }

    private func isInsideParagraph() -> Bool {
        elementStack.contains("p")
    }

    private func isInsideSectionTitle() -> Bool {
        guard let lastBodyIndex = elementStack.lastIndex(of: "body") else { return false }
        let afterBody = elementStack[(lastBodyIndex + 1)...]
        guard let titleIndex = afterBody.firstIndex(of: "title") else { return false }
        return !afterBody[(titleIndex + 1)...].contains("section")
    }

    private func localName(_ name: String) -> String {
        guard let colon = name.firstIndex(of: ":") else { return name }
        return String(name[name.index(after: colon)...])
    }
}
