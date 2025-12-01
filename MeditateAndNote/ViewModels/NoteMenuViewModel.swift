//
//  NoteMenuViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import Foundation

final class NoteMenuViewModel: ObservableObject {
    private let notesService: NotesProtocol
    private let itemManager: AnyItemManager<Note>

    @Published var visibleNotes: [Note] = MockNotes
    var last10Notes: [Note] = []

    let searchState: SearchState
    let uiState: NotesUIState

    //    init(notesService: NotesService) {
    //        self.notesService = notesService
    //        loadNotes()
    //    }

    init(notesService: NotesProtocol, itemManager: AnyItemManager<Note>) {
        self.notesService = notesService
        self.itemManager = itemManager
        self.searchState = SearchState(itemProvider: itemManager)
        self.uiState = NotesUIState()

            self.last10Notes = Array(visibleNotes.suffix(10))
    }

    private func loadNotes() {
        visibleNotes = notesService.fetchNotes()
    }

    func refreshNotes() {
        loadNotes()
    }

    func deleteNote(id: UUID) {
        notesService.deleteNote(id: id)
        refreshNotes()
    }
}
