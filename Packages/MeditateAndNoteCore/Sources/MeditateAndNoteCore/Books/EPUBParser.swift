//
//  EPUBParser.swift
//  MeditateAndNoteCore
//

import Foundation

/// Parses EPUB (OPF spine order + XHTML chapters) into `BookContent`.
///
/// The ZIP container is handled by the platform layer: Core stays
/// dependency-free, the caller provides a file accessor that returns the
/// decompressed bytes for an archive entry path (nil when absent).
public struct EPUBParser: Sendable {
    public typealias FileAccessor = @Sendable (String) -> Data?

    public struct ParseResult: Sendable {
        public let content: BookContent
        public let coverData: Data?
    }

    public init() {}

    public func parse(fileAccessor: FileAccessor) throws -> ParseResult {
        guard let containerData = fileAccessor("META-INF/container.xml") else {
            throw BookParseError.invalidFormat("missing META-INF/container.xml")
        }
        let opfPath = try Self.opfPath(in: containerData)

        guard let opfData = fileAccessor(opfPath) else {
            throw BookParseError.invalidFormat("missing OPF at \(opfPath)")
        }
        let opf = try Self.parseOPF(opfData)
        let baseDir = (opfPath as NSString).deletingLastPathComponent

        var chapters: [BookChapter] = []
        for item in opf.spine {
            guard let entry = opf.manifest[item] else { continue }
            let isText = entry.mediaType == "application/xhtml+xml" || entry.mediaType == "text/html"
            guard isText, !opf.navHrefs.contains(entry.href) else { continue }
            guard let documentData = fileAccessor(Self.resolve(baseDir, entry.href)) else { continue }
            let chapter = Self.parseDocument(documentData, title: nil)
            if !chapter.blocks.isEmpty {
                chapters.append(chapter)
            }
        }

        guard !chapters.isEmpty else {
            throw BookParseError.invalidFormat("no readable chapters in spine")
        }

        let coverData = opf.coverHref
            .flatMap { Self.resolve(baseDir, $0) }
            .flatMap(fileAccessor)

        let content = BookContent(
            title: opf.title,
            author: opf.author,
            chapters: chapters
        ).normalized()
        return ParseResult(content: content, coverData: coverData)
    }

    // MARK: - container.xml / OPF

    private static func opfPath(in containerData: Data) throws -> String {
        let delegate = ContainerDelegate()
        let parser = XMLParser(data: containerData)
        parser.delegate = delegate
        guard parser.parse(), let path = delegate.rootFilePath, !path.isEmpty else {
            throw BookParseError.invalidFormat("container.xml has no rootfile")
        }
        return path
    }

    private static func parseOPF(_ data: Data) throws -> OPF {
        let delegate = OPFDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw BookParseError.invalidFormat("malformed OPF: \(parser.parserError?.localizedDescription ?? "unknown")")
        }
        delegate.resolveDeferredCover()
        return delegate.opf
    }

    private struct OPF {
        var title: String?
        var author: String?
        var coverHref: String?
        var manifest: [String: (href: String, mediaType: String)] = [:]
        var spine: [String] = []
        var navHrefs: Set<String> = []
    }

    private final class ContainerDelegate: NSObject, XMLParserDelegate {
        var rootFilePath: String?
        private var capture = false

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            if localName(elementName) == "rootfile" {
                rootFilePath = attributeDict["full-path"]
                capture = true
            }
        }
    }

    private final class OPFDelegate: NSObject, XMLParserDelegate {
        var opf = OPF()
        private var captureTarget: CaptureTarget?
        private var buffer = ""
        private var currentCoverMetaID: String?

        private enum CaptureTarget { case title, creator }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let name = localName(elementName)
            buffer = ""
            switch name {
            case "title":
                if captureTarget == nil { captureTarget = .title }
            case "creator":
                if captureTarget == nil { captureTarget = .creator }
            case "item":
                let id = attributeDict["id"] ?? ""
                let href = attributeDict["href"] ?? ""
                let mediaType = attributeDict["media-type"] ?? ""
                opf.manifest[id] = (href, mediaType)
                let properties = attributeDict["properties"] ?? ""
                if properties.contains("cover-image"), mediaType.hasPrefix("image/") {
                    opf.coverHref = href
                } else if properties.contains("nav") {
                    opf.navHrefs.insert(href)
                }
            case "itemref":
                if let idref = attributeDict["idref"] {
                    opf.spine.append(idref)
                }
            case "meta":
                if attributeDict["name"] == "cover", let content = attributeDict["content"] {
                    currentCoverMetaID = content
                }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch localName(elementName) {
            case "title":
                if captureTarget == .title, opf.title == nil {
                    opf.title = buffer.collapsedWhitespace()
                }
                captureTarget = nil
            case "creator":
                if captureTarget == .creator, opf.author == nil {
                    opf.author = buffer.collapsedWhitespace()
                }
                captureTarget = nil
            default:
                break
            }
        }

        /// The `<meta name="cover">` convention references a manifest id that
        /// may be declared later than the meta itself; resolve after parsing.
        func resolveDeferredCover() {
            if opf.coverHref == nil, let id = currentCoverMetaID, let item = opf.manifest[id], item.mediaType.hasPrefix("image/") {
                opf.coverHref = item.href
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            buffer += string
        }
    }

    // MARK: - XHTML documents

    private static func parseDocument(_ data: Data, title: String?) -> BookChapter {
        let delegate = XHTMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        if parser.parse(), !delegate.blocks.isEmpty {
            return BookChapter(title: title, blocks: delegate.blocks)
        }
        // Real-world EPUB XHTML occasionally isn't well-formed XML; strip tags.
        return BookChapter(title: title, blocks: Self.stripTags(data))
    }

    private static func stripTags(_ data: Data) -> [BookBlock] {
        let raw = String(decoding: data, as: UTF8.self)
        let body = raw.range(of: "<body").map { String(raw[$0.lowerBound...]) } ?? raw
        let withoutTags = body.replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
        return withoutTags
            .components(separatedBy: "\n")
            .map { $0.htmlUnescaped().collapsedWhitespace() }
            .filter { !$0.isEmpty }
            .map { BookBlock(.paragraph, $0) }
    }

    private final class XHTMLDelegate: NSObject, XMLParserDelegate {
        var blocks: [BookBlock] = []
        private var buffer = ""
        private var depth = 0
        private var skipDepth: Int?
        private var isHeading = false

        private static let headingNames: Set<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]
        private static let skipNames: Set<String> = ["style", "script", "head"]

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let name = localName(elementName)
            depth += 1
            if skipDepth != nil { return }
            if Self.skipNames.contains(name) {
                skipDepth = depth
                return
            }
            if name == "p" || Self.headingNames.contains(name) {
                buffer = ""
                isHeading = Self.headingNames.contains(name)
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let name = localName(elementName)
            if let skipDepth, depth == skipDepth {
                self.skipDepth = nil
                depth -= 1
                return
            }
            if name == "p" || Self.headingNames.contains(name) {
                let text = buffer
                    .replacingOccurrences(of: "\n", with: " ")
                    .collapsedWhitespace()
                if !text.isEmpty {
                    blocks.append(BookBlock(isHeading ? .heading : .paragraph, text))
                }
                buffer = ""
            }
            depth -= 1
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard skipDepth == nil else { return }
            buffer += string
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            guard skipDepth == nil else { return }
            buffer += String(decoding: CDATABlock, as: UTF8.self)
        }
    }

    // MARK: - Helpers

    private static func resolve(_ baseDir: String, _ href: String) -> String {
        let path = href.split(separator: "?").first.map(String.init) ?? href
        if baseDir.isEmpty { return path }
        let components = path.split(separator: "/").map(String.init)
        var result = baseDir.split(separator: "/").map(String.init)
        for component in components {
            if component == ".." {
                _ = result.popLast()
            } else if component != "." {
                result.append(component)
            }
        }
        return result.joined(separator: "/")
    }
}

private func localName(_ name: String) -> String {
    guard let colon = name.firstIndex(of: ":") else { return name }
    return String(name[name.index(after: colon)...])
}

extension String {
    fileprivate func htmlUnescaped() -> String {
        let ampersand = String(UnicodeScalar(38)!)
        let lessThan = String(UnicodeScalar(60)!)
        let greaterThan = String(UnicodeScalar(62)!)
        let quote = String(UnicodeScalar(34)!)
        let apostrophe = String(UnicodeScalar(39)!)
        let entities: [String: String] = [
            ampersand + "nbsp;": " ",
            ampersand + "amp;": ampersand,
            ampersand + "lt;": lessThan,
            ampersand + "gt;": greaterThan,
            ampersand + "quot;": quote,
            ampersand + "apos;": apostrophe,
            ampersand + "#39;": apostrophe,
        ]
        var result = self
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }
}
