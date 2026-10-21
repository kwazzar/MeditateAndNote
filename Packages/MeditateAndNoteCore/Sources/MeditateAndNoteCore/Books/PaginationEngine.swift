//
//  PaginationEngine.swift
//  MeditateAndNoteCore
//

import Foundation

public struct PageSize: Hashable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// A fully laid-out book: flat sequence of pages with logical-position origins.
public struct PaginatedBook: Sendable {
    public struct Page: Hashable, Sendable {
        /// Wrapped lines ready to render verbatim.
        public let lines: [String]
        /// Logical position of each line, parallel to `lines`. A highlight
        /// points at a line, not at a page, so the reader needs the exact
        /// offset of the marked line.
        public let linePositions: [ReadingPosition]
        /// Logical position of the first character on this page.
        public let origin: ReadingPosition
        /// Logical position just past the last character on this page.
        public let end: ReadingPosition
        /// Global character offset of the page start, for progress calculation.
        public let startGlobalOffset: Int
    }

    public let pages: [Page]
    /// Total character count of the laid-out content.
    public let totalCharacters: Int

    public func progress(ofPageAt index: Int) -> Double {
        guard !pages.isEmpty, totalCharacters > 0 else { return 0 }
        let clamped = min(max(index, 0), pages.count - 1)
        return Double(pages[clamped].startGlobalOffset) / Double(totalCharacters)
    }
}

/// Greedy text layout: wraps blocks into lines, fills lines into pages.
/// Chapters and headings start on a new page; paragraphs flow across pages.
public struct PaginationEngine: Sendable {
    private let measurer: any TextMeasurer

    public init(measurer: any TextMeasurer) {
        self.measurer = measurer
    }

    public func paginate(_ content: BookContent, pageSize: PageSize) -> PaginatedBook {
        let lineHeight = measurer.lineHeight()
        let maxLinesPerPage = max(Int(pageSize.height / lineHeight), 1)

        var pages: [PaginatedBook.Page] = []
        var currentLines: [String] = []
        var currentLinePositions: [ReadingPosition] = []
        // (position, global offset) of the first character on the open page.
        var currentOrigin: (position: ReadingPosition, globalOffset: Int)?

        var consumedCharacters = 0
        var blockGlobalStart = 0

        func closePage(end: ReadingPosition) {
            guard let origin = currentOrigin else { return }
            pages.append(
                PaginatedBook.Page(
                    lines: currentLines,
                    linePositions: currentLinePositions,
                    origin: origin.position,
                    end: end,
                    startGlobalOffset: origin.globalOffset
                )
            )
            currentLines = []
            currentLinePositions = []
            currentOrigin = nil
        }

        for (chapterIndex, chapter) in content.chapters.enumerated() {
            // Chapters start on a new page.
            if !currentLines.isEmpty {
                closePage(
                    end: ReadingPosition(
                        chapterIndex: chapterIndex,
                        blockIndex: 0,
                        characterOffset: 0
                    )
                )
            }

            for (blockIndex, block) in chapter.blocks.enumerated() {
                blockGlobalStart = consumedCharacters
                let text = block.text

                // Headings are never split: force a fresh page.
                if block.style == .heading && !currentLines.isEmpty {
                    closePage(
                        end: ReadingPosition(
                            chapterIndex: chapterIndex,
                            blockIndex: blockIndex,
                            characterOffset: -1
                        )
                    )
                }

                let lines = wrap(text, maxWidth: pageSize.width)
                var lineStart = 0

                for line in lines {
                    if currentLines.count >= maxLinesPerPage {
                        closePage(
                            end: ReadingPosition(
                                chapterIndex: chapterIndex,
                                blockIndex: blockIndex,
                                characterOffset: lineStart - 1
                            )
                        )
                    }
                    if currentLines.isEmpty {
                        currentOrigin = (
                            ReadingPosition(
                                chapterIndex: chapterIndex,
                                blockIndex: blockIndex,
                                characterOffset: lineStart
                            ),
                            blockGlobalStart + lineStart
                        )
                    }
                    currentLines.append(line)
                    currentLinePositions.append(
                        ReadingPosition(
                            chapterIndex: chapterIndex,
                            blockIndex: blockIndex,
                            characterOffset: lineStart
                        )
                    )
                    lineStart += line.count + 1
                }

                consumedCharacters += text.count
            }
        }

        if !currentLines.isEmpty {
            let lastChapter = max(content.chapters.count - 1, 0)
            let lastBlock = max((content.chapters.last?.blocks.count ?? 1) - 1, 0)
            closePage(end: ReadingPosition(chapterIndex: lastChapter, blockIndex: lastBlock, characterOffset: 0))
        }

        if pages.isEmpty {
            pages.append(
                PaginatedBook.Page(
                    lines: [],
                    linePositions: [],
                    origin: ReadingPosition(),
                    end: ReadingPosition(),
                    startGlobalOffset: 0
                )
            )
        }

        return PaginatedBook(pages: pages, totalCharacters: consumedCharacters)
    }

    /// Page index containing the given position, or nil when the book is empty.
    /// Positions beyond the content resolve to the last page.
    public func page(of position: ReadingPosition, in paginated: PaginatedBook) -> Int? {
        let pages = paginated.pages
        guard !pages.isEmpty else { return nil }

        var low = 0
        var high = pages.count - 1
        var result = 0
        while low <= high {
            let mid = (low + high) / 2
            if compare(pages[mid].origin, position) <= 0 {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result
    }

    /// Logical position of the first character on the given page.
    public func position(atPage index: Int, in paginated: PaginatedBook) -> ReadingPosition {
        guard !paginated.pages.isEmpty else { return ReadingPosition() }
        return paginated.pages[min(max(index, 0), paginated.pages.count - 1)].origin
    }

    // MARK: - Wrapping

    private func wrap(_ text: String, maxWidth: Double) -> [String] {
        var lines: [String] = []
        for paragraphLine in text.components(separatedBy: "\n") {
            lines.append(contentsOf: wrapLine(paragraphLine, maxWidth: maxWidth))
        }
        return lines
    }

    private func wrapLine(_ line: String, maxWidth: Double) -> [String] {
        let words = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !words.isEmpty else { return [""] }

        var lines: [String] = []
        var current = ""
        var currentWidth = 0.0

        for word in words {
            let wordWidth = measurer.width(of: word)
            let candidateWidth = current.isEmpty ? wordWidth : currentWidth + measurer.width(of: " ") + wordWidth

            if candidateWidth <= maxWidth {
                if !current.isEmpty { current += " " }
                current += word
                currentWidth = candidateWidth
            } else if wordWidth > maxWidth {
                // Word longer than a full line: hard-break by characters.
                if !current.isEmpty {
                    lines.append(current)
                    current = ""
                    currentWidth = 0
                }
                var remainder = Substring(word)
                while !remainder.isEmpty {
                    var fit = ""
                    var fitWidth = 0.0
                    for character in remainder {
                        let characterWidth = measurer.width(of: String(character))
                        if fitWidth + characterWidth > maxWidth { break }
                        fit.append(character)
                        fitWidth += characterWidth
                    }
                    if fit.isEmpty {
                        fit = String(remainder.first ?? " ")
                        remainder = remainder.dropFirst()
                    } else {
                        remainder = remainder.dropFirst(fit.count)
                    }
                    if remainder.isEmpty {
                        current = fit
                        currentWidth = fitWidth
                    } else {
                        lines.append(fit)
                    }
                }
            } else {
                lines.append(current)
                current = word
                currentWidth = wordWidth
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    private func compare(_ lhs: ReadingPosition, _ rhs: ReadingPosition) -> Int {
        if lhs.chapterIndex != rhs.chapterIndex {
            return lhs.chapterIndex < rhs.chapterIndex ? -1 : 1
        }
        if lhs.blockIndex != rhs.blockIndex {
            return lhs.blockIndex < rhs.blockIndex ? -1 : 1
        }
        if lhs.characterOffset != rhs.characterOffset {
            return lhs.characterOffset < rhs.characterOffset ? -1 : 1
        }
        return 0
    }
}
