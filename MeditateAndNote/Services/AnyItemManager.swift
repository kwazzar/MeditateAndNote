//
//  AnyNoteManager.swift
//  MeditateAndNote
//
//  Created by Quasar on 01.12.2025.
//

import Foundation

// Protocols are defined in NoteManager.swift

//MARK: - AnyNoteManager (Type Erasure for NoteProvidable & NoteManagable)
final class AnyNoteManager: NoteProvidable, NoteManagable {
    private let _currentNotes: () async -> [Note]
    private let _noteWith: (NoteID) async throws -> Note?
    private let _notesMatching: (SearchQuery) async -> [Note]
    private let _refresh: () async -> Void
    private let _add: (Note) async throws -> Void
    private let _update: (Note) async throws -> Void
    private let _delete: (NoteID) async throws -> Void

    init<T: NoteProvidable & NoteManagable>(_ manager: T) {
        _currentNotes = { await manager.currentNotes }
        _noteWith = { try await manager.note(with: $0) }
        _notesMatching = { await manager.notes(matching: $0) }
        _refresh = { await manager.refresh() }
        _add = { try await manager.add($0) }
        _update = { try await manager.update($0) }
        _delete = { try await manager.delete(with: $0) }
    }

    var currentNotes: [Note] {
        get async { await _currentNotes() }
    }

    func note(with id: NoteID) async throws -> Note? {
        try await _noteWith(id)
    }

    func notes(matching query: SearchQuery) async -> [Note] {
        await _notesMatching(query)
    }

    func refresh() async {
        await _refresh()
    }

    func add(_ note: Note) async throws {
        try await _add(note)
    }

    func update(_ note: Note) async throws {
        try await _update(note)
    }

    func delete(with id: NoteID) async throws {
        try await _delete(id)
    }
}
