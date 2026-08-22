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
    private let itemManager: AnyNoteManager

    var visibleNotes: [Note] = []
    var error: NoteOperationError?
    var last10Notes: [Note] = []

    let searchState: SearchState

    init(itemManager: AnyNoteManager) {
        self.itemManager = itemManager
        self.searchState = SearchState(itemProvider: itemManager)
        self.searchState.setAvailableItems(visibleNotes)

        self.last10Notes = Array(visibleNotes.suffix(10))
    }
    
    func loadIfNeeded() async {
        await itemManager.refresh()
        await loadNotes()
    }

    private func loadNotes() async {
        visibleNotes = await itemManager.currentNotes
        searchState.setAvailableItems(visibleNotes)
        if !searchState.searchText.text.isEmpty {
            searchState.updateFilteredItems(for: searchState.searchText)
        }
    }

    func refreshNotes() async {
        await loadNotes()
    }

    func deleteNote(_ note: Note) async {
        do {
            try await itemManager.delete(with: note.id)
            await refreshNotes()
        } catch {
            self.error = .deleteFailed(note.id)
            logger.error("Error deleting note — \(error.localizedDescription)")
        }
    }
}
