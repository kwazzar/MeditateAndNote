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
    private let settings: ReaderSettings

    private(set) var book: Book?
    private(set) var paginated: PaginatedBook?
    var currentPage: Int = 0
    private(set) var isLoading = true
    private(set) var loadFailed = false

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
         settings: ReaderSettings = .shared) {
        self.bookID = bookID
        self.manager = manager
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
        }
    }

    /// Usable text area: full screen minus vertical padding and the status/home areas.
    private static func pageSize() async -> PageSize {
        await MainActor.run {
            let screen = UIScreen.main.bounds
            let width = screen.width - 48
            let height = screen.height - 160
            return PageSize(width: Double(width), height: Double(height))
        }
    }
}
