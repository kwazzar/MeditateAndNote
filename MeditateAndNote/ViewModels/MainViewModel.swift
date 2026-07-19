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
    @Published var last10Notes: [Note] = []

    //    init(notesService: NotesService) {
    //        self.notesService = notesService
    //        loadNotes()
    //    }

    init(repository: NotesRepository) {
        self.repository = repository
        self.visibleNotes = visibleNotes

        last10Notes = Array(visibleNotes.suffix(10))
    }

    #warning("force uwrap")
    private func loadNotes() async {
        visibleNotes = try! await repository.getItems(strategy: .remoteFirst)
    }

    func refreshNotes() async {
        await loadNotes()
    }

#warning("force uwrap")
    func deleteNote(id: UUID) async {
        try! await repository.deleteItem(id: id.uuidString, strategy: .remoteFirst)
        await refreshNotes()
    }
}
