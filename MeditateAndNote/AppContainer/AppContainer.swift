//
//  AppContainer.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation
import SwiftUI

final class AppContainer {

    // MARK: - Services (Singletons)
    private let eventBus = DomainEventBus.shared

    private lazy var localDataSource: any NoteDataSource = CoreDataNoteDataSource()
    private lazy var remoteDataSource: any NoteDataSource = InMemoryNoteDataSource()

    private lazy var syncCoordinator: NoteSyncCoordinator = DefaultNoteSyncCoordinator(
        local: localDataSource,
        remote: remoteDataSource
    )

    private(set) lazy var streakTracker = StreakTracker(calendar: .current, store: CoreDataStreakStore())
    private(set) lazy var insightManager = StreakInsightManager(
        snapshotProvider: streakTracker as any StreakSnapshotProvidable
    )
    private(set) lazy var meditationSessionStore = CoreDataSessionStore()
    private let meditationService: MeditationService = SampleMeditationService()
    private(set) lazy var selectionStore = MeditationSelectionStore()
    private(set) lazy var soundSettings = SoundSettings.shared
    private(set) lazy var animationSettings = AnimationSettings.shared
    private(set) lazy var onboardingStore: any OnboardingStore = UserDefaultsOnboardingStore()
    private(set) lazy var reminderManager = ReminderManager(
        store: UserDefaultsReminderSettingsStore(),
        scheduler: SystemNotificationScheduler()
    )

    private lazy var noteManager = NoteManager(syncCoordinator: syncCoordinator, eventBus: eventBus)

    // MARK: - AI Settings

    @MainActor private lazy var aiSettingsStore = AIDraftSettingsStoreObservable()

    // MARK: - AI Draft Services

    private lazy var aiDraftService: any AIDraftService = AIDraftServiceFactory.make()
    private lazy var aiDraftSessionStore: any AIDraftSessionStore = CoreDataAIDraftSessionStore()
    private lazy var aiDraftMetricStore: any AIDraftMetricStore = CoreDataAIDraftMetricStore()
    private lazy var aiDraftManager = AIDraftManager(
        service: aiDraftService,
        store: aiDraftSessionStore,
        eventBus: eventBus
    )

    /// Single shared instance: NoteMenu binds one VM for its whole lifetime,
    /// so the list loads once and stays fresh via domain events. Creating a
    /// fresh VM per render would leak event-bus subscriptions.
    @MainActor
    private(set) lazy var noteMenuViewModel = NoteMenuViewModel(notes: noteManager)

    private var eventsTask: Task<Void, Never>?

    init() {
        startEventListening()
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
    func makeNoteAIDraftViewModel(noteID: NoteID, currentContent: NoteContent) -> NoteAIDraftViewModel {
        NoteAIDraftViewModel(
            noteID: noteID,
            currentContent: currentContent,
            drafts: aiDraftManager,
            eventBus: eventBus
        )
    }

    @MainActor
    func makeAIDraftSettingsViewModel() -> AIDraftSettingsStoreObservable {
        aiSettingsStore
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

    @MainActor
    func makeOnboardingViewModel(onCompletion: @escaping () -> Void) -> OnboardingViewModel {
        OnboardingViewModel(
            store: onboardingStore,
            pages: OnboardingPage.appSlides,
            onCompletion: onCompletion
        )
    }

    @MainActor
    func makeInsightsViewModel() -> InsightsViewModel {
        InsightsViewModel(manager: insightManager)
    }
}

// MARK: - Domain Events

private extension AppContainer {
    /// The single consumer of the bus. Chain:
    ///
    ///     eventBus.publish(event)            // emitter's thread (e.g. NoteManager actor)
    ///     └─ AsyncStream<DomainEvent>.events // bus fans the event out to each consumer
    ///        └─ this Task (for await)        // stored in `eventsTask`, cancellable
    ///           └─ switch, on @MainActor     // handlers may mutate observable/CoreData state
    ///
    /// Events are processed sequentially, in publish order. The bus publishes on the
    /// emitter's thread, so everything here runs on the main actor after a hop.
    func startEventListening() {
        eventsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in self.eventBus.events {
                switch event {
                case .noteCreated, .noteUpdated:
                    await self.streakTracker.handle(event)
                    self.insightManager.handle(event)
                case .noteDeleted(let noteID):
                    await self.streakTracker.handle(event)
                    self.insightManager.handle(event)
                    // When a note is deleted its AI draft sessions are orphans — clean
                    // them up so the store doesn't accumulate rows for notes that no
                    // longer exist.
                    try? await self.aiDraftManager.discardSessions(for: noteID)
                case .meditationCompleted:
                    await self.streakTracker.handle(event)
                    self.insightManager.handle(event)
                    await self.meditationSessionStore.handle(event)
                case .aiDraftGenerated:
                    break
                case .aiDraftMetric:
                    await self.aiDraftMetricStore.handle(event)
                }
            }
        }
    }
}

// MARK: - Environment

private struct AppContainerEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppContainer = AppContainer()
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerEnvironmentKey.self] }
        set { self[AppContainerEnvironmentKey.self] = newValue }
    }
}
