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

    private lazy var localDataSource: any NoteDataSource = CoreDataNoteDataSource()
    private lazy var remoteDataSource: any NoteDataSource = InMemoryNoteDataSource()

    private lazy var syncCoordinator: NoteSyncCoordinator = DefaultNoteSyncCoordinator(
        local: localDataSource,
        remote: remoteDataSource
    )

    private(set) lazy var streakTracker = StreakTracker(calendar: .current, store: CoreDataStreakStore())
    private(set) lazy var meditationSessionStore = CoreDataSessionStore()
    private let meditationService: MeditationService = SampleMeditationService()
    private(set) lazy var selectionStore = MeditationSelectionStore()

    private lazy var noteManager = NoteManager(syncCoordinator: syncCoordinator, eventBus: eventBus)

    /// Single shared instance: NoteMenu binds one VM for its whole lifetime,
    /// so the list loads once and stays fresh via domain events. Creating a
    /// fresh VM per render would leak event-bus subscriptions.
    private(set) lazy var noteMenuViewModel = NoteMenuViewModel(notes: noteManager)

    init() {
        let tracker = streakTracker
        eventBus.subscribe { [weak tracker] event in
            tracker?.handle(event)
        }

        let store = meditationSessionStore
        eventBus.subscribe { [weak store] event in
            store?.handle(event)
        }
    }

    // MARK: - ViewModels Factory Methods

    func makeMainViewModel() -> MainViewModel {
        MainViewModel(
            meditationService: meditationService,
            selectionStore: selectionStore
        )
    }

    func makeNoteViewModel(noteId: NoteID? = nil) -> NoteViewModel {
        NoteViewModel(noteId: noteId, notes: noteManager)
    }

    func makeNoteEditorViewModel(noteId: NoteID? = nil) -> NoteEditorViewModel {
        NoteEditorViewModel(noteId: noteId, notes: noteManager)
    }

    func makeMeditateSelectViewModel() -> MeditateSelectViewModel {
        MeditateSelectViewModel(meditationService: meditationService, selectionStore: selectionStore)
    }

    func makeMeditationViewModel(for meditation: Meditation) -> MeditationViewModel {
        MeditationViewModel(
            meditation: meditation,
            eventBus: eventBus
        )
    }

    func makeNoteMenuViewModel() -> NoteMenuViewModel {
        noteMenuViewModel
    }
}
