//
//  MainViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

final class MainViewModel: ObservableObject {
    private let notesService: NotesService
    @Published var visibleNotes: [Note] = MockNotes
    var last10Notes: [Note] = []

    //    init(notesService: NotesService) {
    //        self.notesService = notesService
    //        loadNotes()
    //    }

    init(notesService: NotesService) {
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
