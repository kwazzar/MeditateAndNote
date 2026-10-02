//
//  AppContainer.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import SwiftUI

final class AppContainer: @unchecked Sendable {

    /// The production instance. `init()` starts the event loop as a side
    /// effect, so production must share one container — otherwise every extra
    /// instance runs its own event loop and its own background managers
    /// (double streak writes, double AI analysis passes). Fresh `init()`s are
    /// only for previews/tests, which intentionally stay isolated.
    static let shared = AppContainer()

    // MARK: - Scopes

    /// Lazy on purpose: every scope opens CoreData stacks and/or loads models
    /// (`NLEmbeddingService`, `AIDraftServiceFactory`). The event loop resolves
    /// them through a closure, so nothing is built until something needs it.
    private lazy var streak = StreakScope()
    private lazy var notes = NoteScope(localDataSource: localDataSource, eventBus: eventBus)
    private lazy var aiDraft = AIDraftScope(eventBus: eventBus)
    private lazy var meditation = MeditationScope()
    private lazy var search = SearchScope()
    private lazy var settings = SettingsScope()

    // MARK: - Core

    private let eventBus = DomainEventBus.shared
    private lazy var localDataSource: any NoteDataSource = CoreDataNoteDataSource()
    private let eventLoop = EventLoopCoordinator()

    // MARK: - Long-lived ViewModels

    /// Single shared instance: NoteMenu binds one VM for its whole lifetime, so
    /// the list loads once and stays fresh via domain events. A fresh VM per
    /// render would leak event-bus subscriptions.
    @MainActor private lazy var noteMenuViewModel = NoteMenuViewModel(notes: notes.manager)
    @MainActor private lazy var noteInsightsViewModel = NoteInsightsViewModel(provider: notes.insightManager, eventBus: eventBus)
    @MainActor private lazy var aiSettingsStore = AIDraftSettingsStoreObservable()

    /// Cached for the same reason as `noteMenuViewModel`: these are created
    /// inside `RootContainer.mainTabBar`, which SwiftUI re-evaluates on every
    /// router/theme/streak/scenePhase change. A factory-allocated VM per pass
    /// meant a fresh `MeditateSelectViewModel` — and its 500ms `loadTask` —
    /// per body pass, plus a `UserDefaults` write from `restoreLastSelected`.
    @MainActor private lazy var mainViewModel = MainViewModel(
        meditationService: meditation.service,
        selectionStore: meditation.selectionStore
    )
    @MainActor private lazy var meditateSelectViewModel = MeditateSelectViewModel(
        meditationService: meditation.service,
        selectionStore: meditation.selectionStore
    )

    // MARK: - Init

    init() {
        eventLoop.start(eventBus: eventBus) { [self] event in
            handlers(for: event)
        }
    }

    /// Resolves only the scopes that actually react to `event`. The
    /// `DomainEventRouting.handles` check is static and allocation-free, so an
    /// event nobody wants (e.g. `.noteInsightsUpdated`) no longer drags
    /// `AIDraftScope`/`SearchScope` out of `lazy` on its way to being dropped.
    @MainActor
    private func handlers(for event: DomainEvent) -> [any DomainEventRouting] {
        var result: [any DomainEventRouting] = []
        if StreakScope.handles(event) { result.append(streak) }
        if NoteScope.handles(event) { result.append(notes) }
        if AIDraftScope.handles(event) { result.append(aiDraft) }
        if MeditationScope.handles(event) { result.append(meditation) }
        if SearchScope.handles(event) { result.append(search) }
        return result
    }

    // MARK: - ViewModels Factory Methods

    @MainActor
    func makeMainViewModel() -> MainViewModel {
        mainViewModel
    }

    @MainActor
    func makeNoteEditorViewModel(noteId: NoteID? = nil) -> NoteEditorViewModel {
        NoteEditorViewModel(noteId: noteId, notes: notes.manager, drafts: aiDraft.manager, eventBus: eventBus)
    }

    @MainActor
    func makeNoteAIDraftViewModel(noteID: NoteID, currentContent: NoteContent) -> NoteAIDraftViewModel {
        NoteAIDraftViewModel(
            noteID: noteID,
            currentContent: currentContent,
            drafts: aiDraft.manager,
            eventBus: eventBus
        )
    }

    @MainActor
    func makeAIDraftSettingsViewModel() -> AIDraftSettingsStoreObservable {
        aiSettingsStore
    }

    @MainActor
    func makeMeditateSelectViewModel() -> MeditateSelectViewModel {
        meditateSelectViewModel
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
    func makeNoteInsightsViewModel() -> NoteInsightsViewModel {
        noteInsightsViewModel
    }

    @MainActor
    func makeOnboardingViewModel(onCompletion: @escaping () -> Void) -> OnboardingViewModel {
        OnboardingViewModel(
            store: settings.onboardingStore,
            pages: OnboardingPage.appSlides,
            onCompletion: onCompletion
        )
    }

    @MainActor
    func makeInsightsViewModel() -> InsightsViewModel {
        InsightsViewModel(manager: streak.insightManager)
    }

    // MARK: - Forwarding (kept so existing call sites don't change)

    var streakTracker: StreakTracker { streak.streakTracker }
    var insightManager: StreakInsightManager { streak.insightManager }
    var meditationSessionStore: CoreDataSessionStore { meditation.store }
    var reminderManager: ReminderManager { settings.reminderManager }
    @MainActor var soundSettings: SoundSettings { settings.soundSettings }
    @MainActor var animationSettings: AnimationSettings { settings.animationSettings }
    var onboardingStore: any OnboardingStore { settings.onboardingStore }
    var noteManager: NoteManager { notes.manager }
    var aiDraftManager: AIDraftManager { aiDraft.manager }
    var aiDraftSessionStore: any AIDraftSessionStore { aiDraft.sessionStore }
    var aiDraftMetricStore: any AIDraftMetricStore { aiDraft.metricStore }
    var embeddingService: any EmbeddingService { search.embeddingService }
    var noteEmbeddingStore: any NoteEmbeddingStore { search.noteEmbeddingStore }
    var semanticSearchManager: SemanticSearchManager { search.manager }
    var noteInsightManager: NoteInsightManager { notes.insightManager }
    var meditationService: MeditationService { meditation.service }
    var selectionStore: MeditationSelectionStore { meditation.selectionStore }
}

// MARK: - Environment

private struct AppContainerEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppContainer = .shared
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerEnvironmentKey.self] }
        set { self[AppContainerEnvironmentKey.self] = newValue }
    }
}
