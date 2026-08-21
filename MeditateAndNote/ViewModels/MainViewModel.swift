//
//  MainViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

final class MainViewModel: ObservableObject {
    private let meditationService: MeditationService
    private let selectionStore: MeditationSelectionStore
    private let notes: any NoteProvidable & NoteManagable
    @Published var visibleNotes: [Note] = []
    @Published var last10Notes: [Note] = []
    @Published var errorMessage: String?

    init(meditationService: MeditationService,
         selectionStore: MeditationSelectionStore,
         notes: any NoteProvidable & NoteManagable) {
        self.meditationService = meditationService
        self.selectionStore = selectionStore
        self.notes = notes

        last10Notes = Array(visibleNotes.suffix(10))
    }

    func lastSelectedMeditation() -> Meditation? {
        guard let id = selectionStore.lastSelectedID else { return nil }
        return meditationService.getMeditations().first(where: { $0.id == id })
    }

    private func loadNotes() async {
        await notes.refresh()
        visibleNotes = await notes.currentItems
    }

    func refreshNotes() async {
        await loadNotes()
    }

    func deleteNote(id: NoteID) async {
        do {
            try await notes.deleteItem(with: id)
            await refreshNotes()
        } catch {
            errorMessage = error.localizedDescription
            print("Error deleting note: \(error)")
        }
    }
}
