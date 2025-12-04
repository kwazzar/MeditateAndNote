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
//    private lazy var repository: NotesRepository = DefaultNotesRepository(InMemoryDataSource: UserDefaultsNotesRepository(), coreDataSource: InMemoryNotesRepository())

    private typealias NotesRepo = Repository<Note, InMemoryNotesDataSource, CoreDataNotesDataSource>

    private lazy var notesRepository: NotesRepo = {
        let local = InMemoryNotesDataSource()
        let remote = CoreDataNotesDataSource()
        return NotesRepo(localDataSource: local, remoteDataSource: remote)
    }()

    private lazy var noteManager = NoteManager(repository: notesRepository)

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
        NoteMenuViewModel(itemManager: AnyItemManager(noteManager))
    }
}
