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
    @MainActor
    private(set) lazy var noteMenuViewModel = NoteMenuViewModel(notes: noteManager)

    init() {
        let tracker = streakTracker
        eventBus.subscribe { [weak tracker] event in
            // Event bus publishes on the emitter's thread (e.g. NoteManager's
            // actor on a background executor). Both observers mutate observable
            // state / Core Data, so hop to the main actor before handling.
            Task { @MainActor in
                await tracker?.handle(event)
            }
        }

        let store = meditationSessionStore
        eventBus.subscribe { [weak store] event in
            Task { @MainActor in
                await store?.handle(event)
            }
        }
    }

    // MARK: - ViewModels Factory Methods

    func makeMainViewModel() -> MainViewModel {
        MainViewModel(
            meditationService: meditationService,
            selectionStore: selectionStore
        )
    }

    @MainActor
    func makeNoteEditorViewModel(noteId: NoteID? = nil) -> NoteEditorViewModel {
        NoteEditorViewModel(noteId: noteId, notes: noteManager)
    }

    @MainActor
    func makeMeditateSelectViewModel() -> MeditateSelectViewModel {
        MeditateSelectViewModel(meditationService: meditationService, selectionStore: selectionStore)
    }

    @MainActor
    func makeMeditationViewModel(for meditation: Meditation) -> MeditationViewModel {
        MeditationViewModel(
            meditation: meditation,
            eventBus: eventBus
        )
    }

    @MainActor
    func makeNoteMenuViewModel() -> NoteMenuViewModel {
        noteMenuViewModel
    }
}
