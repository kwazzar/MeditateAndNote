//
//  MainViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

final class MainViewModel: ObservableObject {
    private let repository: NotesRepository
    @Published var visibleNotes: [Note] = MockNotes
    var last10Notes: [Note] = []

    //    init(notesService: NotesService) {
    //        self.notesService = notesService
    //        loadNotes()
    //    }

    init(repository: NotesRepository) {
        self.repository = repository
        self.visibleNotes = visibleNotes

        last10Notes = Array(visibleNotes.suffix(10))
    }

    private func loadNotes() {
        visibleNotes = repository.fetchAll()
    }

    func refreshNotes() {
        loadNotes()
    }

    func deleteNote(id: UUID) {
        repository.delete(id: id)
        refreshNotes()
    }
}
