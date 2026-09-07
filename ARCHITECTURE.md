# MeditateAndNote — Architecture

Domain-Driven Design (DDD) app. SwiftUI + CoreData + `@Observable`, custom
Router-based navigation, per-domain `DataSource`/`Store` protocols, Managers
split into read/write (`<X>Providable` / `<X>Manageable`) boundaries, and
async / actor-backed persistence (Swift Concurrency safe).

Dependencies point inward toward the domain:

```
Presentation (SwiftUI Views, ViewModels)
        ↓
Application (NoteManager, StreakTracker, StreakInsightManager,
            ReminderManager, MeditationSessionEngine adapters, ...)
        ↓
Domain (Entities, Value Objects, DataSource/Store protocols)
        ↑
Infrastructure (Persistence/ — CoreData + UserDefaults implementations)
```

The Domain layer never imports `CoreData`/`SwiftUI`/`UIKit`. NSManagedObject
maps to domain models only inside the concrete DataSource/Store.

> **Swift Concurrency view.** Persistence paths are concurrency-safe:
> `NoteManager` and `InMemoryNoteDataSource` are actors, CoreData data sources
> use `context.perform`/`await`, view models that touch observable state are
> `@MainActor`, and the single `DomainEventBus` is a lock-based
> `DomainEventPublisher` with a synchronous `nonisolated` `publish` that runs
> on the emitter's thread. Subscribers hop onto `@MainActor` before mutating
> observable/CoreData state.

## App Entry & Dependency Injection

```mermaid
graph TB
    subgraph Entry["App Entry"]
        App["MeditateAndNoteApp<br/>@main"]
        Router["Router<br/>@Observable<br/>Navigation State"]
        Container["AppContainer<br/>plain class<br/>DI Factory"]
        Theme["ThemeManager<br/>@Observable<br/>UserDefaults"]
        Streak["StreakTracker<br/>@Observable<br/>engine + store"]
        SessionStore["CoreDataSessionStore<br/>@Observable"]
        Insights["StreakInsightManager"]
        Reminders["ReminderManager<br/>@Observable"]
    end

    App -->|"@State + environment"| Router
    App -->|"@State + appContainer env"| Container
    App -->|"@State"| Theme
    App -->|"environment"| Streak
    App -->|"environment"| SessionStore
    App -->|"environment"| Reminders
    App -->|"root view"| Root
```

`AppContainer` is the DI root. It owns the singletons (DomainEventBus, data
sources, sync coordinator, managers) and exposes `make<X>ViewModel()` factory
methods; it never acts as a registration container. Mutation paths that leak
into `init` subscribe `StreakTracker`, `CoreDataSessionStore`, and
`StreakInsightManager` to `DomainEventBus`, each hopping to `@MainActor`.

Factored ViewModel constructors:

- `makeMainViewModel()` → `MainViewModel(meditationService, selectionStore)`
- `makeNoteEditorViewModel(noteId:)` → `NoteEditorViewModel(noteId, noteManager)`
- `makeMeditateSelectViewModel()` → `MeditateSelectViewModel(...)`
- `makeMeditationViewModel(for:)` → `MeditationViewModel(meditation, eventBus, soundPlayer)`
- `makeNoteMenuViewModel()` → the shared singleton `NoteMenuViewModel`
- `makeOnboardingViewModel(onCompletion:)` → `OnboardingViewModel(store, pages, onCompletion)`
- `makeInsightsViewModel()` → `InsightsViewModel(StreakInsightManager)`

## Root & Navigation

```mermaid
graph TB
    subgraph Root["Root Container"]
        RootView["RootContainer<br/>StartupFlow + TabView + CustomTabBar<br/>+ onboarding gating"]
        Onb["OnboardingCoordinator<br/>store + Router transition"]
        OnbVM["OnboardingViewModel<br/>@Observable<br/>pages + completion"]
    end

    RootView -->|"shouldShowOnboarding ?"| Onb
    Onb -->|"onOnboardingCompleted(router)"| RootView
    Onb --> OnbVM

    RootView -->|"Tab: .home"| NavHome
    RootView -->|"Tab: .notes"| NavNotes
    RootView -->|"Tab: .meditations"| NavMeditations

    subgraph Tabs["Tab Navigation"]
        NavHome["NavigationContainer<br/>childRouter(home)"]
        NavNotes["NavigationContainer<br/>childRouter(notes)"]
        NavMeditations["NavigationContainer<br/>childRouter(meditations)"]
    end

    subgraph Nav["Navigation Model"]
        Dest["Destination<br/>tab / push / sheet / fullScreen"]
        Push["PushDestination<br/>newNote, noteDetails, readingView,<br/>meditation, meditationCompletion,<br/>streakDetail, settings"]
        Sheet["SheetDestination<br/>newNote (stub), meditationSettings<br/>(stub), timeMeditation"]
        Full["FullScreenDestination<br/>meditationSession, fullScreenNote"]
        Deep["DeepLinkParser<br/>myScheme://..."]
    end

    Dest --> Push
    Dest --> Sheet
    Dest --> Full
    Router --> Dest
    NavHome --> Deep
```

- `RootContainer` gates launch on `OnboardingCoordinator` (`shouldShowOnboarding`),
  showing onboarding before the tab bar mounts. A DEBUG `-showOnboarding`
  launch arg reopens it for dev.
- `Router` is a level-aware `@Observable` class holding `navigationStackPath`,
  `presentingSheet`, `presentingFullScreen`, `isDetailPresented`, and
  `selectedTab`. Children are created via `childRouter(for:)`; only the active
  router resolves deep links. It is injected via `@Environment(Router.self)` —
  views read it non-optionally (Observation tracks only what a body actually
  reads), and `NavigationContainer` owns its child router in `@State`, wrapping
  it in a local `@Bindable` for `NavigationStack`/sheet bindings.
- `Destination` wraps `PushDestination`/`SheetDestination`/`FullScreenDestination`.
  Since the last update `.settings`, `.meditationCompletion` pushes and the
  `.meditationSession` full screen were added; `newNote`/`meditationSettings`
  sheet cases are currently mapped to `EmptyView()` stubs.
- `NavigationContainer` wraps each tab in a `NavigationStack` bound to its
  router, and maps destinations to concrete views via
  `Destination-ViewMapping.swift` + `ContainerView`.
- `NavigationContainer` exposes only the router and a view builder; it never
  holds screen logic. ViewModels never reference a concrete View.

## Views & ViewModels

```mermaid
graph TB
    subgraph Views["Views"]
        MainView["MainView<br/>Home Tab"]
        NoteMenu["NoteMenu<br/>Notes Tab"]
        MeditateSelect["MeditateSelectView<br/>Meditations Tab"]
        NoteEditor["NoteEditorView<br/>Note Editor"]
        MeditationView["MeditationView<br/>Active Session"]
        MeditationCompletion["MeditationCompletionView"]
        ReadingView["ReadingView<br/>Post-Meditation"]
        StreakDetail["StreakDetailView<br/>InsightsSection, WeekdayHeatmap,
<br/>LifetimePatternsSection, StreakDayDetailSheet"]
        SettingsView["SettingsView<br/>Reminder / Animation / Theme / Sound"]
        OnboardingView["OnboardingView<br/>OnboardingPageView"]
        TimeSheet["TimeMeditationSheet"]
        MeditationInfo["MeditationInfoScroll"]
    end

    subgraph ViewModels["ViewModels"]
        MainVM["MainViewModel<br/>@Observable"]
        NoteMenuVM["NoteMenuViewModel<br/>@Observable<br/>singleton"]
        NoteEditorVM["NoteEditorViewModel<br/>@Observable<br/>EditTarget state machine"]
        MeditateSelectVM["MeditateSelectViewModel<br/>@Observable<br/>loadState"]
        MeditationVM["MeditationViewModel<br/>@MainActor @Observable<br/>wraps MeditationSessionEngine"]
        InsightsVM["InsightsViewModel<br/>@Observable<br/>range + lifetime"]
        OnboardingVM["OnboardingViewModel<br/>@MainActor @Observable"]
    end

    MainView --> MainVM
    NoteMenu --> NoteMenuVM
    NoteEditor --> NoteEditorVM
    MeditateSelect --> MeditateSelectVM
    MeditationView --> MeditationVM
    StreakDetail --> InsightsVM
    OnboardingView --> OnboardingVM

    MainVM -->|uses| MeditSvc["MeditationService"]
    MainVM -->|uses| SelStore["MeditationSelectionStore"]
    MeditateSelectVM -->|uses| MeditSvc
    MeditateSelectVM -->|uses| SelStore
    NoteMenuVM -->|uses any NoteProvidable & NoteManageable| NM["NoteManager"]
    NoteEditorVM -->|uses any NoteProvidable & NoteManageable| NM
    InsightsVM -->|uses any StreakInsightProvidable| IM["StreakInsightManager"]
```

Note: `NoteMenuViewModel` is a singleton in `AppContainer` (loaded once,
keeps its event-bus subscription alive). `NoteEditorViewModel`,
`MeditationViewModel`, `OnboardingViewModel`, and `InsightsViewModel` are
created per screen via `make<X>ViewModel()`.

## Domain Model

```mermaid
graph LR
    subgraph Models["Domain Models (plain Swift, no CoreData/SwiftUI)"]
        Note["Note<br/>id, title, content, date"]
        NoteBook["NoteBook<br/>aggregate: one entry per id,<br/>last-write-wins"]
        MergeConflict["MergeConflict"]
        Meditation["Meditation<br/>id, title, breathingStyle, category"]
        BreathingStyle["BreathingStyle<br/>fourSevenEight, box,<br/>fourEight, custom"]
        BreathingPattern["BreathingPattern<br/>name, phases"]
        BreathingPhase["BreathingPhase<br/>type, duration"]
        MeditationCategory["MeditationCategory<br/>mindfulness, breathing, sleep,<br/>focus, relaxation"]
        Session["MeditationSession<br/>id, meditationId,<br/>completedAt, duration"]
        SessionDuration["SessionDuration<br/>positive invariant"]
        Engine["MeditationSessionEngine<br/>pure state machine"]
        Clock["BreathingClock<br/>pure timing"]
        DayState["CoreDayState<br/>empty / meditationOnly /<br/>noteOnly / complete"]
        DailyAct["DailyActivity<br/>date, hasMeditation, hasNote,<br/>meditationTime, noteTime"]
        DayDetail["StreakDayDetail<br/>date, state, missingAction"]
        StreakEngine["StreakEngine<br/>pure streak logic"]
        InsightVO["StreakInsight / UserRecommendation /<br/>StreakLengthDistribution /<br/>StreakResilience / WeeklyBucket /<br/>WeekdayHeatmapData / StreakRange"]
        RemindVO["ReminderSettings +<br/>ReminderScheduleBuilder<br/>(pure scheduling math)"]
        Search["SearchQuery / NoteFilter"]
        MainTheme["MainTheme<br/>liquidGlass, breathing, softDawn,<br/>darkZen, obsidian"]
    end

    Meditation --> BreathingStyle
    BreathingStyle --> BreathingPattern
    BreathingPattern --> BreathingPhase
    Meditation --> MeditationCategory
    Engine --> Clock
    Engine --> SessionDuration
    Session --> SessionDuration
    DailyAct --> DayState
    DayDetail --> DayState
    StreakEngine --> DailyAct
    Note -- aggregate --> NoteBook
    NoteBook -.-> MergeConflict
```

Domain invariants live in the Value Objects / aggregate / engines:
- `NoteTitle` trims and supplies `"Untitled"`; `NoteContent` is a wrapper.
- `NoteBook` owns collection invariants (one row per `NoteID`, LWW by date).
- `SessionDuration` rejects non-positive values even on the constructor path,
  and `SessionDuration` decoder path throws rather than allowing bad data.
- `DailyActivity` exposes a first-class `CoreDayState`
  (`empty / meditationOnly / noteOnly / complete`); `.complete` is the only
  streak-contributing state. `markMeditation`/`markNote` set the boolean and
  its timestamp atomically.
- `ReminderSettings` clamps `hour`/`minute` and guarantees a non-empty,
  valid weekday set; `ReminderScheduleBuilder` computes fire dates with pure
  calendar math (no `UNUserNotificationCenter`).
- `MeditationSessionEngine` is a deterministic state machine
  (`idle → countdown → active → finished`). `active` carries a wall-clock
  `anchoredAt` and a `finishing` flag — remaining time is derived from real
  elapsed time (timer drift / backgrounding can't overrun), and the session
  closes on an exhale phase boundary rather than mid-inhale. All side effects
  come back as `Event`s instead of being fired inline.
- `StreakEngine` holds the pure streak rules; `StreakTracker` is an `@Observable`
  adapter over it and forwards to `StreakActivityStore`. `StreakInsightEngine`
  (pure) + `StreakInsightManager` (cached) derive range-aware insights and
  lifetime patterns (distribution, resilience, break heatmap) from a
  `StreakSnapshot`.

## Application / Services Layer

```mermaid
graph TB
    subgraph App["Application Services"]
        NM["NoteManager<br/>actor<br/>NoteProvidable & NoteManageable"]
        Sync["NoteSyncCoordinator<br/>protocol + Default impl<br/>local/remote strategies"]
        MeditSvc["MeditationService<br/>protocol + SampleMeditationService"]
        SelStore["MeditationSelectionStore<br/>UserDefaults"]
        StreakTracker["StreakTracker<br/>@Observable<br/>StreakSnapshotProvidable"]
        InsightMgr["StreakInsightManager<br/>StreakInsightProvidable<br/>cached"]
        ReminderMgr["ReminderManager<br/>@Observable<br/>ReminderProvidable & ReminderManageable"]
        OnbStore["OnboardingStore<br/>protocol + UserDefaultsOnboardingStore"]
        ThemeManager["ThemeManager<br/>@Observable"]
        Sound["SoundPlayer<br/>SoundPlaying protocol"]
        Bus["DomainEventBus<br/>DomainEventPublisher"]

        NoteProv["NoteProvidable<br/>currentNotes, note(with:),<br/>notes(matching:), refresh"]
        NoteMan["NoteManageable<br/>add, update, delete"]
        InsightProv["StreakInsightProvidable<br/>insights(for:), recommendations(for:),<br/>weeklyBreakdown, streakLengthDistribution,<br/>resilience, weekdayBreakPattern,<br/>weekdayBreakHeatmap"]
        RemindProv["ReminderProvidable / ReminderManageable"]

        Evt["DomainEvent<br/>noteCreated / noteUpdated /<br/>noteDeleted / meditationCompleted"]
    end

    NM --- NoteProv
    NM --- NoteMan
    NM --> Sync
    NM --> Bus
    StreakTracker ---- InsightMgr
    InsightMgr --- InsightProv
    ReminderMgr --- RemindProv
    OnbStore -.->|"implements"| UserDefaultsOnboardingStore
    StreakTracker --> Bus
    InsightMgr --> Bus
    ReminderMgr -->|"implements"| RemindProv
    Sound -->|"implements"| SoundP["SoundPlaying"]
    Bus --> Evt
```

`Services/` is grouped by domain folder rather than flat: `Notes/`
(`NoteManager`, `NotesRepository`, `NoteSyncCoordinator`), `Meditation/`
(`MeditationService`), `Events/` (`DomainEvents`), `Reminders/`
(`ReminderManager`, `NotificationScheduling`), `Settings/`
(`AnimationSettings`), `Onboarding/` (`OnboardingStore`), `Theme/`
(`ThemeManager`), plus `Sound/` (`SoundPlayer`, `SoundSettings`) and `Streak/`
(`StreakTracker`, `StreakInsightEngine`, `StreakInsightManager`).

- **`NoteManager`** (actor) is the application service for notes. It exposes
  two protocols: `NoteProvidable` (read) and `NoteManageable` (write), plus a
  typed `NoteOperationError` (`.loadFailed` / `.saveFailed` / `.deleteFailed`).
  It holds its own `NoteBook` aggregate (rebuilt from the sync coordinator
  after each mutation) and publishes domain events. ViewModels depend on
  `any NoteProvidable & NoteManageable`.
- **`NoteSyncCoordinator`** (`DefaultNoteSyncCoordinator`) orchestrates
  local/remote reads and writes by `SyncStrategy` (`localOnly`, `remoteOnly`,
  `localFirst`, `remoteFirst`, `hybrid`). Hybrid merges via
  `NoteBook.merged` and reports `MergeConflict`s; remote writes are best-effort
  (`bestEffort`) so local data is safe even if remote sync fails.
- **`StreakTracker`** is an `@Observable` adapter over the pure `StreakEngine`
  (`StreakSnapshotProvidable` read boundary). **`StreakInsightManager`** depends
  on `any StreakSnapshotProvidable` (not the concrete tracker) and exposes
  `StreakInsightProvidable` — range-aware insights/recommendations plus
  lifetime patterns, with per-(range, signature) memoization invalidated by
  domain events.
- **`ReminderManager`** (ReminderProvidable / ReminderManageable) orchestrates
  `ReminderSettings` with a `NotificationScheduling` abstraction; every
  mutation persists and reschedules a 7-day notification horizon.
- **Domain events** decouple bounded contexts: `DomainEvent` is a closed sum
  type; subscribers (`StreakTracker`, `CoreDataSessionStore`,
  `StreakInsightManager`, `NoteMenuViewModel`) switch exhaustively, so adding a
  case is a compile-time decision. The bus publishes on the emitter's thread;
  subscribers hop to `@MainActor` before mutating observable/CoreData state.

## Infrastructure (Persistence)

```mermaid
graph TB
    subgraph SQLite["CoreData (programmatic model, no .xcdatamodeld)"]
        CDM["CoreDataManager<br/>NSPersistentContainer<br/>buildModel(), newBackgroundContext()"]
        CDNote["CoreDataNoteDataSource<br/>conforms NoteDataSource"]
        CDStreak["CoreDataStreakStore<br/>conforms StreakActivityStore"]
        CDSession["CoreDataSessionStore<br/>concrete store (accepted exception)<br/>@Observable"]

        CDEvent["CDNote / CDMeditationSession /<br/>CDDailyActivity / CDStreakMeta<br/>NSManagedObject entities"]
    end

    subgraph Contracts["Persistence Protocols (Domain)"]
        ND["NoteDataSource<br/>fetchAll / fetch(id:) / save /<br/>delete(id:) / deleteAll"]
        SA["StreakActivityStore<br/>load / save snapshot"]
        RS["ReminderSettingsStore<br/>load / save ReminderSettings"]
        NS["NotificationScheduling<br/>isAuthorized / requestAuthorization /<br/>scheduleNotification / removeAllPending"]
        OS["OnboardingStore<br/>hasCompletedOnboarding /<br/>markOnboardingCompleted"]
        IM["InMemoryNoteDataSource<br/>actor · conforms NoteDataSource<br/>(tests & previews)"]
        UDS["UserDefaultsStreakStore<br/>conforms StreakActivityStore<br/>+ legacy migration"]
        UDReminder["UserDefaultsReminderSettingsStore<br/>conforms ReminderSettingsStore"]
        SysSched["SystemNotificationScheduler<br/>conforms NotificationScheduling<br/>(UNUserNotificationCenter)"]
        UDOnb["UserDefaultsOnboardingStore<br/>conforms OnboardingStore"]
    end

    CDNote -.-> ND
    IM -.-> ND
    CDStreak -.-> SA
    UDS -.-> SA
    UDReminder -.-> RS
    SysSched -.-> NS
    UDOnb -.-> OS
    CDNote --> CDM
    CDStreak --> CDM
    CDSession --> CDM
    CDNote --> CDEvent
    CDStreak --> CDEvent
    CDSession --> CDEvent
```

- `CoreDataManager` owns the `NSPersistentContainer` and builds the model
  programmatically (CDNote, CDMeditationSession, CDDailyActivity, CDStreakMeta).
  Only DataSources/Stores touch it. If the disk store fails to load it falls
  back to an in-memory store so the app stays usable.
- All NSManagedObject → domain mapping stays inside the concrete
  DataSource/Store (`.toNote()`, `.apply()`, `.findOrCreate()`).
- `CoreDataSessionStore` is a known accepted exception — a concrete `@Observable`
  type with no protocol abstraction (unlike `CoreDataStreakStore`, which
  conforms to `StreakActivityStore`).
- Async / actor persistence: CoreData data sources route I/O through
  `context.perform` / `await context.perform`; `InMemoryNoteDataSource` is an
  actor. These live in `Persistence/` plus `Services/` (streak/reminder store
  protocols and their UserDefaults impls keep the Domain free of framework
  imports).

## Data Flow

```mermaid
sequenceDiagram
    participant User
    participant Tab as RootContainer<br/>TabView
    participant Nav as NavigationContainer
    participant View as Screen View
    participant VM as ViewModel
    participant Container as AppContainer
    participant Mgr as Manager / Store
    participant DS as DataSource / CoreData

    User->>Tab: Selects tab
    Tab->>Nav: Routes to child Router
    Nav->>View: Displays screen

    User->>View: Taps action
    View->>VM: Delegates to ViewModel
    VM->>Mgr: Any NoteProvidable & NoteManageable
    Mgr->>DS: Local (CoreData) + remote
    DS-->>Mgr: Returns domain model
    Mgr-->>VM: Updates @Observable state
    VM-->>View: UI re-renders
    Mgr--)Bus: Publishes DomainEvent (noteCreated/meditationCompleted)
    Bus--)Streak/CoreDataSessionStore/StreakInsightManager: Reacts (@MainActor hop)

    Note over View,Container: On Navigation
    View->>Nav: router.navigate(to: .push / .sheet / .fullScreen)
    Nav->>Container: ContainerView resolves VM via factory
    Container->>View: Creates destination View with VM
```

## Navigation State Machine

```mermaid
stateDiagram-v2
    [*] --> Home: Tab .home
    [*] --> Notes: Tab .notes
    [*] --> Meditations: Tab .meditations

    Home --> Meditation: Push .meditation(meditation)
    Home --> NoteDetail: Push .noteDetails(noteId)
    Home --> Streak: Push .streakDetail
    Home --> Settings: Push .settings

    Notes --> NoteDetail: Push .noteDetails(noteId)
    Notes --> NewNote: Push .newNote

    Meditations --> MeditationInfo: Sheet .meditationSettings
    Meditations --> Meditation: Push .meditation(meditation)

    Meditation --> TimePicker: Sheet .timeMeditation
    Meditation --> Reading: Push .readingView (after finish)
    Meditation --> Completion: Push .meditationCompletion (after finish)
    Meditation --> Home: Close

    state Meditation {
        [*] --> Idle
        Idle --> Countdown: start(duration)
        Countdown --> Active: tickCountdown
        Active --> Paused: pause
        Paused --> Active: resume
        Active --> Finished: tickSecond
        Finished --> [*]: .meditationCompleted
    }
```

`MeditationViewModel` drives the `MeditationSessionEngine` timer loop; on
`.completed` it builds a `MeditationSession` and publishes
`.meditationCompleted` on the `DomainEventBus`, which `CoreDataSessionStore`
persists, `StreakTracker` feeds into the streak engine, and
`StreakInsightManager` uses to invalidate its cache. The schedule no longer
requires an on-screen `ReadingView` — a `MeditationCompletionView` push is
available via `.meditationCompletion(meditation:duration:)`.
