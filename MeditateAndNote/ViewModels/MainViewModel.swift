//
//  MainViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

final class MainViewModel: ObservableObject {
    private let meditationService: MeditationService
    private let repository: NotesRepository
    @Published var visibleNotes: [Note] = MockNotes
    @Published var last10Notes: [Note] = []
    @Published var errorMessage: String?

    //    init(notesService: NotesService) {
    //        self.notesService = notesService
    //        loadNotes()
    //    }

    init(meditationService: MeditationService, repository: NotesRepository) {
        self.meditationService = meditationService
        self.repository = repository
        self.visibleNotes = visibleNotes

        last10Notes = Array(visibleNotes.suffix(10))
    }
    
    func getMeditation() throws -> Meditation {
        let lastSelectedId = UserDefaults.standard.string(forKey: "lastSelectedMeditationId") ?? "default_meditation_id"

        guard let meditation = meditationService.getMeditations().first(where: { $0.id == lastSelectedId }) else {
            throw MeditationError.notFound(id: lastSelectedId)
        }
        return meditation
    }

    private func loadNotes() async {
        do {
            visibleNotes = try await repository.getItems(strategy: .remoteFirst)
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading notes: \(error)")
        }
    }

    func refreshNotes() async {
        await loadNotes()
    }

    func deleteNote(id: UUID) async {
        do {
            try await repository.deleteItem(id: id.uuidString, strategy: .remoteFirst)
            await refreshNotes()
        } catch {
            errorMessage = error.localizedDescription
            print("Error deleting note: \(error)")
        }
    }
}
