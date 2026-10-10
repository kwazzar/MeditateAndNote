# Screens, JNI status, porting order

JNI impl = a Kotlin implementation / generated `com.mn.core.*` type reachable from
the Android build. "Ported" = a Compose screen exists under
`Android/app/src/main/java/com/mn/android/ui/`.

| Screen (iOS View) | ViewModel | Managers/Stores | Android JNI impl | Ported |
|---|---|---|---|---|
| OnboardingView | OnboardingViewModel | OnboardingStore | ✓ `OnboardingStore.kt` | ✓ `OnboardingScreen` |
| MainView (tab home) | MainViewModel | MeditationService, MeditationSelectionStore, StreakTracker→StreakActivityStore | ✓ `SampleMeditationService`+`MeditationSelection`; ✓ `StreakSnapshotStore` | partial — `HomeScreen` placeholder, no streak header |
| MeditateSelectView (tab meditations) | MeditateSelectViewModel | MeditationService, MeditationSelectionStore | ✓ | ✓ `MeditateSelectScreen` (minus sound sheet) |
| MeditationView (session) | MeditationViewModel | MeditationSessionEngine, SoundPlayer, DomainEventBus, MeditationSessionStore | Engine ✓, Session ✓; SoundPlayer ✗; Bus ✗ | partial `BreathingScreen` |
| MeditationCompletionView | (same VM flow) | DomainEventBus, MeditationSessionStore | Bus ✗ | ✓ (FinishedView) |
| TimeMeditationSheet | MeditationViewModel | MeditationDuration | ✓ | ✓ (DurationSheet) |
| SoundSettingsSheet | SoundSettings | SoundPlaying | ✗ | ✗ |
| NoteMenu (tab notes) | NoteMenuViewModel | NoteManager→NoteDataSource, DomainEventBus, SemanticSearchManager/NoteEmbeddingStore | DataSource ✓; Bus ✗; embedding ✗ | ✓ (manual resume-reload fallback) |
| NoteEditorView | NoteEditorViewModel | NoteManager ✓, AIDraftManager (AIDraftSession/AIDraftSettings stores), eventBus ✗ | `AIDraft*` java gen ✓; Kotlin impls ✗ (only metric Room) | ✓ (AI draft bar deferred) |
| NoteInsightsSection | NoteInsightsViewModel | NoteInsightManager/NoteInsightStore, eventBus | store gen ✓; Kotlin impl ✗ | ✗ |
| StreakDetailView | InsightsViewModel | StreakInsightManager/StreakActivityStore | Store ✓; `StreakInsightEngine` gen but blocked (plan Фаза 5) | ✓ stats/calendar/sheet (Insights deferred) |
| SettingsView | none (View + `@Bindable` managers) | ReminderManager/ReminderSettingsStore ✓; SoundSettings ✗; AnimationSettings ✗; ThemeManager | only Reminder ✓ | ✓ (reminders + onboarding replay; theme/sound/AI deferred) |
| AIDraftSettingsView | AIDraftSettingsStoreObservable | AIDraftSettingsStore | ✗ | ✗ |
| ReadingView | none (placeholder) | — | — | ✗ |
| LoadingScreenView / RootContainer / CustomTabBar | none | Router | nav graph exists; tab shell ✗ | ✗ |

## Reusable Kotlin store implementations already in `Android/.../data/`

- `NoteBlobStore.kt` — `NoteDataSource` (proven on device, `NoteProbe`)
- `StreakSnapshotStore.kt` — `StreakActivityStore` (proven, `StreakProbe`)
- `SessionBlobStore.kt` — `MeditationSessionStore` (proven, `SessionProbe`)
- `SharedPrefsReminderSettingsStore.kt` — `ReminderSettingsStore` (proven, `ReminderSettingsProbe`)
- `OnboardingStore.kt`, `MeditationSelection.kt`, `MeditationCatalog.kt` — Kotlin-only mirrors
- `AiDraftMetricDao.kt` — Room DAO for AI metrics (only AIDraft persistence impl that exists)
- Swift adapters: `Packages/MeditateAndNoteCoreJNI/Sources/.../Kotlin<X>Store.swift`

## Missing JNI (blocks its screen) — report, don't stub

- **`DomainEventBus`**: Java generated (`Core/.generated/java/com/mn/core/DomainEventBus.java`,
  `native $publish/$subscribe`) but **no Swift thunk** in `MeditateAndNoteCoreJNI/Generated/`
  → not callable from Kotlin. Blocks NoteMenu, NoteInsights, completion. Fix by regenerating
  the thunks (the `DomainEventSubscriber` protocol was proven on device, plan §5).
- `SoundPlaying` / ExoPlayer, `SecureStore`, `ReminderScheduler` (AlarmManager),
  AI (`AICore` / ML Kit), `AIDraftSettingsStore`, `AIDraftSessionStore` Kotlin impls,
  `NoteInsightStore` Kotlin impl, `NoteEmbeddingStore`.
- `StreakInsightEngine` is generated but blocked on JNI (plan Фаза 5).

## Recommended porting order (no missing JNI first)

1. Tab shell — `RootContainer`/`CustomTabBar` → `NavigationBar` + nested `NavHost` (no JNI)
2. `MainView` streak header (StreakActivityStore ✓)
3. ~~`NoteMenu`~~ (done ✓, resume-reload fallback)
4. ~~`NoteEditor`~~ (done ✓)
5. ~~`TimeMeditationSheet` + `MeditationCompletion`~~ (done ✓)
6. ~~`Settings`~~ (done ✓ reminders + onboarding replay; theme/sound/AI deferred)
7. ~~`StreakDetail`~~ (done ✓ stats/grid/sheet; **Insights sections pending** — engine blocked)
8. AI-dependent last — `AIDraftSettingsView`, `NoteInsights`, `SoundSettingsSheet`
   (SoundPlayer/ExoPlayer, AICore — plan Фаза 3)
