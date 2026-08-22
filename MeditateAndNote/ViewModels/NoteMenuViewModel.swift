//
//  NoteMenuViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import Foundation
import OSLog

@Observable
final class NoteMenuViewModel {
    private let logger = Logger(subsystem: Config.bundleID, category: "NoteMenuViewModel")
    private let notes: any NoteProvidable & NoteManageable

    #warning("mock notes should be replaced with real implementation or []")
    var visibleNotes: [Note] = MockNotes
    var error: NoteOperationError?
    var last10Notes: [Note] = []

    let searchState: SearchState

    init(notes: any NoteProvidable & NoteManageable) {
        self.notes = notes
        self.searchState = SearchState(itemProvider: notes)
    }
    
    func loadIfNeeded() async {
        await notes.refresh()
        await loadNotes()
    }

    private func loadNotes() async {
        visibleNotes = await notes.currentNotes
        searchState.setAvailableItems(visibleNotes)
        if searchState.searchText != .all {
            searchState.updateFilteredItems(for: searchState.searchText)
        }
    }

    func refreshNotes() async {
        await loadNotes()
    }

    func deleteNote(_ note: Note) async {
        do {
            try await notes.delete(with: note.id)
            await refreshNotes()
        } catch {
            self.error = .deleteFailed(note.id)
            logger.error("Error deleting note — \(error.localizedDescription)")
        }
    }
}
