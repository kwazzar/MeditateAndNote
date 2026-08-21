//
//  AppContainer.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation

final class AppContainer: ObservableObject {
    
    // MARK: - Services (Singletons)
    private let eventBus = DomainEventBus.shared
    
    private lazy var localDataSource: any NoteDataSource = UserDefaultsNoteDataSource()
    private lazy var remoteDataSource: any NoteDataSource = InMemoryNoteDataSource()
    
    private lazy var noteRepository: NoteRepository = DefaultNoteRepository(dataSource: localDataSource)
    private lazy var syncCoordinator: NoteSyncCoordinator = DefaultNoteSyncCoordinator(
        local: localDataSource,
        remote: remoteDataSource
    )
    
    private(set) lazy var streakTracker = StreakTracker()
    private(set) lazy var meditationSessionStore = MeditationSessionStore()
    private let meditationService: MeditationService = SampleMeditationService()
    
    private lazy var noteManager = NoteManager(
        syncCoordinator: syncCoordinator,
        noteRepository: noteRepository
    )

    init() {
        eventBus.subscribe(streakTracker)
    }
    
    // MARK: - ViewModels Factory Methods
    
    func makeMainViewModel() -> MainViewModel {
        MainViewModel(meditationService: meditationService, noteRepository: noteRepository)
    }
    
    func makeNoteViewModel(noteId: UUID? = nil) -> NoteViewModel {
        NoteViewModel(
            noteId: noteId.map(NoteID.init(rawValue:)),
            noteRepository: noteRepository,
            syncCoordinator: syncCoordinator
        )
    }

    func makeNoteEditorViewModel(noteId: UUID? = nil) -> NoteEditorViewModel {
        NoteEditorViewModel(
            noteId: noteId.map(NoteID.init(rawValue:)),
            noteRepository: noteRepository,
            syncCoordinator: syncCoordinator
        )
    }
    
    func makeMeditateSelectViewModel() -> MeditateSelectViewModel {
        MeditateSelectViewModel(meditationService: meditationService)
    }
    
    func makeMeditationViewModel(for meditation: Meditation) -> MeditationViewModel {
        MeditationViewModel(
            meditation: meditation,
            sessionStore: meditationSessionStore
        )
    }
    
func makeNoteMenuViewModel() -> NoteMenuViewModel {
        NoteMenuViewModel(itemManager: AnyItemManager(noteManager))
    }
}

