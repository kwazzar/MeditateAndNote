//
//  NoteMenuViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import Foundation

final class NoteMenuViewModel: ObservableObject {
    private let itemManager: AnyItemManager<Note>

    @Published var visibleNotes: [Note] = MockNotes
    @Published var errorMessage: String?
    var last10Notes: [Note] = []

    let searchState: SearchState
    let uiState: NotesUIState

    //    init(notesService: NotesService) {
    //        self.notesService = notesService
    //        loadNotes()
    //    }

    init(itemManager: AnyItemManager<Note>) {
        self.itemManager = itemManager
        self.searchState = SearchState(itemProvider: itemManager)
        self.uiState = NotesUIState()

            self.last10Notes = Array(visibleNotes.suffix(10))
    }
    
    func loadIfNeeded() async {
        await itemManager.refresh()
    }

    private func loadNotes() async {
        visibleNotes = await itemManager.currentItems
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
