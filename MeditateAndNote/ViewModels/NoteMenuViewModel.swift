//
//  NoteMenuViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import Foundation

final class NoteMenuViewModel: ObservableObject {
    private let notesService: NotesProtocol
    @Published var visibleNotes: [Note] = MockNotes
    var last10Notes: [Note] = []

    //    init(notesService: NotesService) {
    //        self.notesService = notesService
    //        loadNotes()
    //    }

    init(notesService: NotesProtocol) {
        self.notesService = notesService
        self.visibleNotes = visibleNotes

        last10Notes = Array(visibleNotes.suffix(10))
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
