//
//  ReaderViewModel.swift
//  MeditateAndNote
//

import Foundation
import Observation
import SwiftUI
import MeditateAndNoteCore

@MainActor
@Observable
final class ReaderViewModel {
    let bookID: BookID

    private let manager: any BookProvidable & BookManageable
    private let bookmarks: any BookmarkProvidable & BookmarkManageable
    private let settings: ReaderSettings

    private(set) var book: Book?
    private(set) var paginated: PaginatedBook?
    var currentPage: Int = 0
    private(set) var isLoading = true
    private(set) var loadFailed = false

    /// The book's chapters with the page each one starts on.
    private(set) var tableOfContents: [ChapterEntry] = []
    /// The reader's marks in this book, newest last.
    private(set) var marks: [Bookmark] = []

    private var content: BookContent?
    private var paginationTask: Task<Void, Never>?

    var pageCount: Int { paginated?.pages.count ?? 0 }
    var progress: Double { paginated?.progress(ofPageAt: currentPage) ?? 0 }
    var canGoBack: Bool { currentPage > 0 }
    var canGoForward: Bool { currentPage < pageCount - 1 }

    var fontSize: CGFloat {
        get { settings.fontSize }
        set {
            settings.fontSize = newValue
            repaginateKeepingPosition()
        }
    }

    var theme: ReaderTheme {
        get { settings.theme }
        set { settings.theme = newValue }
    }

    var scrollMode: Bool {
        get { settings.scrollMode }
        set { settings.scrollMode = newValue }
    }

    // MARK: - Table of contents

    /// A chapter and the page it starts on.
    struct ChapterEntry: Identifiable, Hashable {
        let id: Int
        let title: String
        let page: Int
    }

    /// Rebuilds the chapter list against the current layout.
    func rebuildTableOfContents() {
        guard let paginated, let content else {
            tableOfContents = []
            return
        }
        var entries: [ChapterEntry] = []
        for (index, chapter) in content.chapters.enumerated() {
            guard let page = paginated.pages.firstIndex(where: { $0.origin.chapterIndex == index }) else {
                continue
            }
            entries.append(
                ChapterEntry(
                    id: index,
                    title: chapter.title?.isEmpty == false ? chapter.title! : "Chapter \(index + 1)",
                    page: page
                )
            )
        }
        tableOfContents = entries
    }

    // MARK: - Marks

    func loadMarks() async {
        marks = (try? await bookmarks.bookmarks(for: bookID)) ?? []
    }

    /// The logical position of the page currently shown.
    func currentPosition() -> ReadingPosition {
        guard let paginated else { return ReadingPosition() }
        return PaginationEngine(measurer: UITextMeasurer(fontSize: settings.fontSize))
            .position(atPage: currentPage, in: paginated)
    }

    /// Position of a line on the current page (used for highlights).
    func position(ofLineAt index: Int) -> ReadingPosition {
        guard let paginated,
              let page = paginated.pages.indices.contains(currentPage) ? paginated.pages[currentPage] : nil,
              page.linePositions.indices.contains(index) else {
            return currentPosition()
        }
        return page.linePositions[index]
    }

    func addBookmark() async {
        let mark = Bookmark.page(bookID, at: currentPosition())
        try? await bookmarks.add(mark)
        await loadMarks()
    }

    func deleteMark(_ mark: Bookmark) async {
        try? await bookmarks.delete(id: mark.id)
        await loadMarks()
    }

    /// Highlights a line and optionally writes a note with the passage.
    func createHighlight(line: String, lineIndex: Int, asNote: Bool) async {
        let position = position(ofLineAt: lineIndex)
        let location = "page \(currentPage + 1)"
        try? await bookmarks.createHighlight(
            bookID: bookID,
            position: position,
            text: line,
            bookTitle: book?.title ?? "",
            location: location,
            asNote: asNote
        )
        await loadMarks()
    }

    // MARK: - Navigation

    func jump(to page: Int) {
        guard pageCount > 0 else { return }
        currentPage = min(max(page, 0), pageCount - 1)
        persistPosition()
    }

    /// Re-layout (font size or rotation change) that lands on the same
    /// logical position, not the same page index.
    func repaginateKeepingPosition() {
        guard let paginated else { return }
        let position = PaginationEngine(measurer: UITextMeasurer(fontSize: settings.fontSize))
            .position(atPage: currentPage, in: paginated)
        repaginate(restoring: position)
    }

    init(bookID: BookID,
         manager: any BookProvidable & BookManageable,
         bookmarks: any BookmarkProvidable & BookmarkManageable,
         settings: ReaderSettings = .shared) {
        self.bookID = bookID
        self.manager = manager
        self.bookmarks = bookmarks
        self.settings = settings
    }

    // MARK: - Lifecycle

    func load() async {
        isLoading = true
        loadFailed = false
        do {
            let (book, content, position) = try await manager.loadContent(for: bookID)
            self.book = book
            self.content = content
            try? await manager.markOpened(bookID)
            await repaginate(restoring: position)
            await loadMarks()
        } catch {
            loadFailed = true
        }
        isLoading = false
    }

    // MARK: - Paging

    func goToNextPage() {
        guard canGoForward else { return }
        currentPage += 1
        persistPosition()
    }

    func goToPreviousPage() {
        guard canGoBack else { return }
        currentPage -= 1
        persistPosition()
    }

    /// Called when the view disappears / scene backgrounds.
    func persistPosition() {
        guard let paginated else { return }
        let position = PaginationEngine(measurer: UITextMeasurer(fontSize: settings.fontSize))
            .position(atPage: currentPage, in: paginated)
        Task {
            try? await manager.saveReadingPosition(position, for: bookID)
        }
    }

    // MARK: - Pagination

    /// Lays the content out for the current font size. Runs on a background
    /// task; a stale result never overwrites a newer one.
    private func repaginate(restoring position: ReadingPosition? = nil) {
        paginationTask?.cancel()
        guard let content else { return }

        let fontSize = settings.fontSize
        let layoutTask = Task.detached(priority: .userInitiated) {
            let measurer = UITextMeasurer(fontSize: fontSize)
            let engine = PaginationEngine(measurer: measurer)
            let pageSize = await Self.pageSize()
            return engine.paginate(content, pageSize: pageSize)
        }
        paginationTask = Task { [weak self] in
            let result = await layoutTask.value
            guard let self, !Task.isCancelled else { return }
            self.paginated = result
            if let position {
                let engine = PaginationEngine(measurer: UITextMeasurer(fontSize: fontSize))
                self.currentPage = engine.page(of: position, in: result) ?? 0
            } else {
                self.currentPage = min(self.currentPage, result.pages.count - 1)
            }
            self.rebuildTableOfContents()
        }
    }

    /// Usable text area: full screen minus the notch/home areas and a small
    /// margin, so the page fills the screen like the FBReader reference.
    private static func pageSize() async -> PageSize {
        await MainActor.run {
            let screen = UIScreen.main.bounds
            let width = screen.width - 40
            let height = screen.height - 112
            return PageSize(width: Double(width), height: Double(height))
        }
    }
}
