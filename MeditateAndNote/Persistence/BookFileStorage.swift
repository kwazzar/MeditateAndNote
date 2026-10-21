//
//  BookFileStorage.swift
//  MeditateAndNote
//
//  Owns book files on disk: import (copy into Application Support/Books),
//  load (decompress EPUB entries as needed), delete.
//

import Foundation
import MeditateAndNoteCore
import ZIPFoundation

struct BookFileStorage: Sendable {

    enum StorageError: Error {
        case fileMissing
        case copyFailed
    }

    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = support.appendingPathComponent("Books", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    // MARK: - Import

    /// Copies a security-scoped file into storage. Returns the stored file name.
    func importBook(from sourceURL: URL, id: BookID, format: BookFormat) throws -> String {
        let fileName = "\(id.rawValue.uuidString).\(format.rawValue)"
        let destination = directory.appendingPathComponent(fileName)

        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } catch {
            throw StorageError.copyFailed
        }
        return fileName
    }

    // MARK: - Load

    func fileURL(for book: Book) -> URL {
        directory.appendingPathComponent(book.fileName)
    }

    /// Loads raw book bytes. For EPUB returns the zip archive itself;
    /// use `entryLoader(for:)` to read individual EPUB entries.
    func loadData(for book: Book) throws -> Data {
        let url = fileURL(for: book)
        guard let data = try? Data(contentsOf: url) else {
            throw StorageError.fileMissing
        }
        return data
    }

    /// File accessor for `EPUBParser`: decompresses a single zip entry.
    func entryLoader(for book: Book) -> @Sendable (String) -> Data? {
        let archiveURL = fileURL(for: book)
        return { path in
            guard let archive = Archive(url: archiveURL, accessMode: .read),
                  let entry = archive[path] else {
                return nil
            }
            var data = Data()
            let bufferSize = 64 * 1024
            do {
                _ = try archive.extract(entry, bufferSize: bufferSize) { chunk in
                    data.append(chunk)
                }
            } catch {
                return nil
            }
            return data
        }
    }

    // MARK: - Delete

    func deleteBook(_ book: Book) {
        try? FileManager.default.removeItem(at: fileURL(for: book))
    }
}
