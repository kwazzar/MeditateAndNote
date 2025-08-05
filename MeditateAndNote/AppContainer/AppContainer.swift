//
//  AppContainer.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation

final class AppContainer: ObservableObject {

    // MARK: - Services (Singletons)
    lazy var notesService: NotesService = NotesService()
    lazy var meditationService: MeditationService = SampleMeditationService()

    // MARK: - ViewModels Factory Methods
    func makeMainViewModel() -> MainViewModel {
        MainViewModel(notesService: notesService)
    }

    func makeNoteViewModel(noteId: String? = nil) -> NoteViewModel {
        NoteViewModel(notesService: notesService)
    }

    func makeMeditateSelectViewModel() -> MeditateSelectViewModel {
        MeditateSelectViewModel(meditationService: meditationService)
    }

    func makeMeditationViewModel(id: String) -> MeditationViewModel {
        let meditation = meditationService.getMeditations()
            .first { $0.id == id }!
        return MeditationViewModel(meditation: meditation)
    }
}
