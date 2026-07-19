//
//  AppContainer.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation

typealias NotesRepository = Repository<Note,
                                       UserDefaultsNotesRepository,
                                       InMemoryNotesDataSource>

final class AppContainer: ObservableObject {

//    static let shared = AppContainer()
//    lazy var sharedNoteViewModel: NoteViewModel = makeNoteViewModel()

    // MARK: - Services (Singletons)
//    private lazy var notesService: NotesProtocol = NotesService()
    private lazy var meditationService: MeditationService = SampleMeditationService()
//    private lazy var repository: NotesRepository = DefaultNotesRepository(InMemoryDataSource: UserDefaultsNotesRepository(), coreDataSource: InMemoryNotesRepository())

    private lazy var notesRepository: NotesRepository = {
        let local = UserDefaultsNotesRepository()
        let remote = InMemoryNotesDataSource()
        return NotesRepository(localDataSource: local, remoteDataSource: remote)
    }()

    private lazy var noteManager =  NoteManager(repository: notesRepository)

    // MARK: - ViewModels Factory Methods
    func makeMainViewModel() -> MainViewModel {
        MainViewModel(repository: notesRepository)
    }

    func makeNoteViewModel(noteId: UUID? = nil) -> NoteViewModel {
        NoteViewModel(noteId: noteId, repository: notesRepository)
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
        let manager = noteManager
        Task { await manager.refreshFromRemote() }
        return NoteMenuViewModel(itemManager: AnyItemManager(manager))
    }
}

