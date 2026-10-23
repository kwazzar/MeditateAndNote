//
//  LibraryViewModel.swift
//  MeditateAndNote
//

import Foundation
import Observation
import MeditateAndNoteCore

@MainActor
@Observable
final class LibraryViewModel {
    private let books: any BookProvidable & BookManageable

    private(set) var library: [Book] = []
    private(set) var covers: [BookID: Data] = [:]
    var importErrorMessage: String?

    init(books: any BookProvidable & BookManageable) {
        self.books = books
    }

    func load() async {
        await books.refresh()
        library = await books.currentBooks
        await loadCovers()
    }

    func importBook(from url: URL) async {
        do {
            _ = try await books.importBook(from: url)
            await load()
        } catch BookImportError.unsupportedFile {
            importErrorMessage = "Unsupported format. Use .fb2, .epub or .txt"
        } catch BookImportError.unreadable {
            importErrorMessage = "Could not read this file. It is not a valid book."
        } catch {
            importErrorMessage = "Import failed. Try another file."
        }
    }

    func delete(_ book: Book) async {
        try? await books.delete(with: book.id)
        await load()
    }

    func progress(for book: Book) async -> Double {
        await books.progress(for: book.id)
    }

    private func loadCovers() async {
        var result: [BookID: Data] = [:]
        for book in library {
            if let cover = await books.coverData(for: book.id) {
                result[book.id] = cover
            }
        }
        covers = result
    }
}
