//
//  AppContainer.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation

final class AppContainer: ObservableObject {

//    static let shared = AppContainer()
//    lazy var sharedNoteViewModel: NoteViewModel = makeNoteViewModel()

    // MARK: - Services (Singletons)
//    private lazy var notesService: NotesProtocol = NotesService()
    private lazy var meditationService: MeditationService = SampleMeditationService()
    private lazy var repository: NotesRepository = InMemoryNotesRepository()
    private lazy var noteManager = NoteManager(repository: repository)

    // MARK: - ViewModels Factory Methods
    func makeMainViewModel() -> MainViewModel {
        MainViewModel(repository: repository)
    }

    func makeNoteViewModel(noteId: UUID? = nil) -> NoteViewModel {
        NoteViewModel(noteId: noteId, repository: repository)
    }

    func makeMeditateSelectViewModel() -> MeditateSelectViewModel {
        MeditateSelectViewModel(meditationService: meditationService)
    }

    func makeMeditationViewModel(id: String) -> MeditationViewModel {
        let meditation = meditationService.getMeditations()
            .first { $0.id == id }!
        return MeditationViewModel(meditation: meditation)
    }

    func makeNoteMenuView() -> NoteMenuViewModel {
        NoteMenuViewModel(itemManager: AnyItemManager(noteManager))
    }
}
