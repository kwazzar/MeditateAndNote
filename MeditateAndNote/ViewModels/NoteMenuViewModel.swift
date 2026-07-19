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

    private func loadNotes() async {
        visibleNotes = await itemManager.currentItems
    }

    func refreshNotes() async {
        await loadNotes()
    }

    #warning("force unwrap")
    func deleteNote(_ note: Note) async {
        try! await itemManager.deleteItem(note)
        await refreshNotes()
    }
}
