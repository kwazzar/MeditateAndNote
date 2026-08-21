//
//  NoteMenuViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import Foundation

@Observable
final class NoteMenuViewModel {
    private let itemManager: AnyItemManager

    var visibleNotes: [Note] = MockNotes
    var errorMessage: String?
    var last10Notes: [Note] = []

    let searchState: SearchState

    init(itemManager: AnyItemManager) {
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
        visibleNotes = await itemManager.currentItems
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
            try await itemManager.deleteItem(note)
            await refreshNotes()
        } catch {
            errorMessage = error.localizedDescription
            print("Error deleting note: \(error)")
        }
    }
}
