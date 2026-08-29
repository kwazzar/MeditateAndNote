# MeditateAndNote — Architecture

Domain-Driven Design (DDD) app. SwiftUI + CoreData + `@Observable`, custom
Router-based navigation, per-domain `DataSource`/`Store` protocols, and a
`NoteManager` split into `NoteProvidable` / `NoteManageable`.

Dependencies point inward toward the domain:

```
Presentation (SwiftUI Views, ViewModels)
        ↓
Application (NoteManager, StreakTracker, MeditationSessionEngine adapters, ...)
        ↓
Domain (Entities, Value Objects, DataSource/Store protocols)
        ↑
Infrastructure (Persistence/ — CoreData implementations)
```

The Domain layer never imports `CoreData`/`SwiftUI`/`UIKit`. NSManagedObject
maps to domain models only inside the concrete DataSource/Store.

## App Entry & Dependency Injection

```mermaid
graph TB
    subgraph Entry["App Entry"]
        App["MeditateAndNoteApp<br/>@main"]
        Router["Router<br/>ObservableObject<br/>Navigation State"]
        Container["AppContainer<br/>ObservableObject<br/>DI Factory"]
        Theme["ThemeManager<br/>@Observable<br/>UserDefaults"]
        Streak["StreakTracker<br/>@Observable<br/>engine + store"]
        SessionStore["CoreDataSessionStore<br/>@Observable"]
    end

    App -->|"@StateObject"| Router
    App -->|"@StateObject"| Container
    App -->|"@State"| Theme
    App -->|"environmentObject"| Streak
    App -->|"environmentObject"| SessionStore
    App -->|"root view"| Root
```

`AppContainer` is the DI root. It owns the singletons (event bus, data
sources, sync coordinator, managers) and exposes `make<X>ViewModel()` factory
methods; it never acts as a registration container.

## Root & Navigation

```mermaid
graph TB
    subgraph Root["Root Container"]
        RootView["RootContainer<br/>TabView + CustomTabBar"]
    end

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
        Push["PushDestination<br/>newNote, noteDetails, readingView,<br/>meditation, streakDetail"]
        Sheet["SheetDestination<br/>newNote, meditationSettings, timeMeditation"]
        Full["FullScreenDestination<br/>meditationSession, fullScreenNote"]
        Deep["DeepLinkParser<br/>myScheme://..."]
    end

    Dest --> Push
    Dest --> Sheet
    Dest --> Full
    Router --> Dest
    NavHome --> Deep
```

- `Router` is a level-aware `ObservableObject` holding `navigationStackPath`,
  `presentingSheet`, `presentingFullScreen`, and `selectedTab`. Children are
  created via `childRouter(for:)`; only the active router resolves deep links.
- `NavigationContainer` wraps each tab in a `NavigationStack` bound to its
  router, and maps `PushDestination`/`SheetDestination`/`FullScreenDestination`
  to concrete views via `Destination-ViewMapping.swift` + `ContainerView`.
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
        ReadingView["ReadingView<br/>Post-Meditation"]
        StreakDetail["StreakDetailView"]
        TimeSheet["TimeMeditationSheet"]
        MeditationInfo["MeditationInfoScroll"]
    end

    subgraph ViewModels["ViewModels"]
        MainVM["MainViewModel<br/>ObservableObject"]
        NoteMenuVM["NoteMenuViewModel<br/>@Observable"]
        NoteEditorVM["NoteEditorViewModel<br/>@Observable<br/>EditTarget state machine"]
        MeditateSelectVM["MeditateSelectViewModel<br/>ObservableObject"]
        MeditationVM["MeditationViewModel<br/>@Observable<br/>wraps MeditationSessionEngine"]
    end

    MainView --> MainVM
    NoteMenu --> NoteMenuVM
    NoteEditor --> NoteEditorVM
    MeditateSelect --> MeditateSelectVM
    MeditationView --> MeditationVM

    MainVM -->|uses| MeditSvc["MeditationService"]
    MainVM -->|uses| SelStore["MeditationSelectionStore"]
    MeditateSelectVM -->|uses| MeditSvc
    MeditateSelectVM -->|uses| SelStore
    NoteMenuVM -->|uses any NoteProvidable & NoteManageable| NM["NoteManager"]
    NoteEditorVM -->|uses any NoteProvidable & NoteManageable| NM
```

Note: `NoteMenuViewModel` is a singleton in `AppContainer` (loaded once,
keeps its event-bus subscription alive). `NoteEditorViewModel` and
`MeditationViewModel` are created per screen via `make<X>ViewModel()`.

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
        DailyAct["DailyActivity<br/>date, hasMeditation, hasNote"]
        StreakEngine["StreakEngine<br/>pure streak logic"]
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
    StreakEngine --> DailyAct
    Note -- aggregate --> NoteBook
    NoteBook -.-> MergeConflict
```

Domain invariants live in the Value Objects / aggregate / engines:
- `NoteTitle` trims and supplies `"Untitled"`; `NoteContent` is a wrapper.
- `NoteBook` owns collection invariants (one row per `NoteID`, LWW by date).
- `SessionDuration` rejects non-positive values even on the constructor path.
- `MeditationSessionEngine` is a deterministic state machine
  (`idle → countdown → active → finished`); all side effects come back as
  `Event`s instead of being fired inline.
- `StreakEngine` holds the pure streak rules; `StreakTracker` is an `@Observable`
  adapter over it and forwards to `StreakActivityStore`.

## Application / Services Layer

```mermaid
graph TB
    subgraph App["Application Services"]
        NM["NoteManager<br/>actor<br/>NoteProvidable & NoteManageable"]
        Sync["NoteSyncCoordinator<br/>protocol + Default impl<br/>local/remote strategies"]
        MeditSvc["MeditationService<br/>protocol + SampleMeditationService"]
        SelStore["MeditationSelectionStore<br/>UserDefaults"]
        StreakTracker["StreakTracker<br/>@Observable"]
        ThemeManager["ThemeManager<br/>@Observable"]
        Sound["SoundPlayer<br/>SoundPlaying protocol"]
        Bus["DomainEventBus<br/>DomainEventPublisher"]

        NoteProv["NoteProvidable<br/>currentNotes, note(with:),<br/>notes(matching:), refresh"]
        NoteMan["NoteManageable<br/>add, update, delete"]


        Evt["DomainEvent<br/>noteCreated / noteUpdated /<br/>noteDeleted / meditationCompleted"]
    end

    NM --- NoteProv
    NM --- NoteMan
    NM --> Sync
    NM --> Bus
    StreakTracker --> Bus
    Sound -->|"implements"| SoundP["SoundPlaying"]
    Bus --> Evt
```

- **`NoteManager`** (actor) is the application service for notes. It exposes
  two protocols: `NoteProvidable` (read) and `NoteManageable` (write), plus a
  typed `NoteOperationError` (`.loadFailed` / `.saveFailed` / `.deleteFailed`).
  It holds its own `NoteBook` aggregate and publishes domain events after each
  mutation. ViewModels depend on `any NoteProvidable & NoteManageable`.
- **`NoteSyncCoordinator`** (`DefaultNoteSyncCoordinator`) orchestrates
  local/remote reads and writes by `SyncStrategy` (`localOnly`, `remoteOnly`,
  `localFirst`, `remoteFirst`, `hybrid`). Hybrid merges via
  `NoteBook.merged` and reports `MergeConflict`s.
- **Domain events** decouple bounded contexts: `DomainEvent` is a closed sum
  type; subscribers (`StreakTracker`, `CoreDataSessionStore`,
  `NoteMenuViewModel`) switch exhaustively, so adding a case is a compile-time
  decision.

## Infrastructure (Persistence)

```mermaid
graph TB
    subgraph SQLite["CoreData (programmatic model, no .xcdatamodeld)"]
        CDM["CoreDataManager<br/>NSPersistentContainer<br/>buildModel(), newBackgroundContext()"]
        CDNote["CoreDataNoteDataSource<br/>conforms NoteDataSource"]
        CDStreak["CoreDataStreakStore<br/>conforms StreakActivityStore"]
        CDSession["CoreDataSessionStore<br/>concrete store (accepted exception)"]

        CDEvent["CDNote / CDMeditationSession /<br/>CDDailyActivity / CDStreakMeta<br/>NSManagedObject entities"]
    end

    subgraph Contracts["Persistence Protocols (Domain)"]
        ND["NoteDataSource<br/>fetchAll / fetch(id:) / save /<br/>delete(id:) / deleteAll"]
        SA["StreakActivityStore<br/>load / save snapshot"]
        IM["InMemoryNoteDataSource<br/>conforms NoteDataSource<br/>(tests & previews)"]
        UDS["UserDefaultsStreakStore<br/>conforms StreakActivityStore<br/>+ legacy migration"]
    end

    CDNote -.-> ND
    IM -.-> ND
    CDStreak -.-> SA
    UDS -.-> SA
    CDNote --> CDM
    CDStreak --> CDM
    CDSession --> CDM
    CDNote --> CDEvent
    CDStreak --> CDEvent
    CDSession --> CDEvent
```

- `CoreDataManager` owns the `NSPersistentContainer` and builds the model
  programmatically (CDNote, CDMeditationSession, CDDailyActivity, CDStreakMeta).
  Only DataSources/Stores touch it.
- All NSManagedObject → domain mapping stays inside the concrete
  DataSource/Store (`.toNote()`, `.apply()`, `.findOrCreate()`).
- `CoreDataSessionStore` is a known accepted exception — a concrete `@Observable`
  type with no protocol abstraction (unlike `CoreDataStreakStore`, which
  conforms to `StreakActivityStore`).

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
    Mgr-->>VM: Updates @Observable / @Published
    VM-->>View: UI re-renders
    Mgr--)Bus: Publishes DomainEvent (noteCreated/meditationCompleted)
    Bus--)Streak/CoreDataSessionStore: Reacts

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

    Notes --> NoteDetail: Push .noteDetails(noteId)
    Notes --> NewNote: Push .newNote

    Meditations --> MeditationInfo: Sheet .meditationSettings
    Meditations --> Meditation: Push .meditation(meditation)

    Meditation --> TimePicker: Sheet .timeMeditation
    Meditation --> Reading: Push .readingView (after finish)
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
persists and `StreakTracker` feeds into the streak engine.
