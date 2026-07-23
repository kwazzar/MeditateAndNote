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
        MainViewModel(meditationService: SampleMeditationService(), repository: notesRepository)
    }

    func makeNoteViewModel(noteId: UUID? = nil) -> NoteViewModel {
        NoteViewModel(noteId: noteId, repository: notesRepository)
    }

    func makeMeditateSelectViewModel() -> MeditateSelectViewModel {
        MeditateSelectViewModel(meditationService: meditationService)
    }

    func makeMeditationViewModel(for meditation: Meditation) -> MeditationViewModel {
        return MeditationViewModel(meditation: meditation)
    }
    
    func makeNoteMenuView() -> NoteMenuViewModel {
        return NoteMenuViewModel(itemManager: AnyItemManager(noteManager))
    }
}

