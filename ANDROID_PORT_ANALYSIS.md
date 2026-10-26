# iOS UI → Android port analysis

> Phase A output. Read-only analysis of the SwiftUI UI layer (screens, Router,
> ThemeManager) vs what already exists on Android. Companion to `ANDROID_PORT_PLAN.md`.
> Analysis date: 2026-10-09.

## 1. Screens

| Screen (iOS View) | ViewModel | Managers/Stores | Android JNI impl | Ported |
|---|---|---|---|---|
| OnboardingView | OnboardingViewModel | OnboardingStore | ✓ `OnboardingStore.kt` | ✓ `OnboardingScreen` |
| MainView (tab home) | MainViewModel | MeditationService, MeditationSelectionStore, StreakTracker→StreakActivityStore | ✓ `SampleMeditationService`+`MeditationSelection`; ✓ `StreakSnapshotStore` | partial — `HomeScreen` placeholder, no streak header |
| MeditateSelectView (tab meditations) | MeditateSelectViewModel | MeditationService, MeditationSelectionStore | ✓ | ✓ `MeditateSelectScreen` (minus sound sheet) |
| MeditationView (session) | MeditationViewModel | MeditationSessionEngine, SoundPlayer, DomainEventBus, MeditationSessionStore | Engine ✓, Session ✓; SoundPlayer ✗; Bus ✗ | partial `BreathingScreen` |
| MeditationCompletionView | (same VM flow) | DomainEventBus, MeditationSessionStore | Bus ✗ | ✗ |
| TimeMeditationSheet | MeditationViewModel | MeditationDuration | ✓ | ✗ |
| SoundSettingsSheet | SoundSettings | SoundPlaying | ✗ | ✗ |
| NoteMenu (tab notes) | NoteMenuViewModel | NoteManager→NoteDataSource, DomainEventBus, SemanticSearchManager/NoteEmbeddingStore | DataSource ✓; Bus ✗; embedding ✗ | ✗ |
| NoteEditorView | NoteEditorViewModel | NoteManager ✓, AIDraftManager (AIDraftSession/AIDraftSettings stores), eventBus ✗ | `AIDraft*` java gen ✓; Kotlin impls ✗ (only metric Room) | ✗ |
| NoteInsightsSection | NoteInsightsViewModel | NoteInsightManager/NoteInsightStore, eventBus | store gen ✓; Kotlin impl ✗ | ✗ |
| StreakDetailView | InsightsViewModel | StreakInsightManager/StreakActivityStore | Store ✓; `StreakInsightEngine` gen but blocked (plan Фаза 5) | ✗ |
| SettingsView | none (View + `@Bindable` managers) | ReminderManager/ReminderSettingsStore ✓; SoundSettings ✗; AnimationSettings ✗; ThemeManager | only Reminder ✓ | ✗ |
| AIDraftSettingsView | AIDraftSettingsStoreObservable | AIDraftSettingsStore | ✗ | ✗ |
| ReadingView | none (placeholder) | — | — | ✗ |
| LoadingScreenView / RootContainer / CustomTabBar | none | Router | nav graph exists; tab shell ✗ | ✗ |

**Bus gap (resolved on the Kotlin side):** the Core `DomainEventBus` cannot
cross JNI — `jextract` cannot express its `AsyncStream` nor the `DomainEvent`
enum with payloads, and `Scripts/build-android.sh` drops those bindings on
purpose. Android therefore runs its own transport, `domain/events/DomainEventBus.kt`
(a Kotlin `SharedFlow`): the editor and the session recorder publish, the
notes list, the insights and the streak screens subscribe. The domain rules
and the side effects (the streak marking) stay in Swift; the bus only carries
the fact that something changed. Core-bus parity over JNI stays optional and
unimplemented.

## 2. Component mapping (SwiftUI → Compose/M3)

| SwiftUI | Compose / M3 | Seen in |
|---|---|---|
| `List` | `LazyColumn` | 1 |
| `ScrollView` | `Column`+`verticalScroll` / `LazyColumn` | many |
| `.sheet` | `ModalBottomSheet` | 4 |
| `.fullScreenCover` | full-screen `Dialog` / nav destination | 1 |
| `.alert` / `confirmationDialog` | `AlertDialog` | 2 |
| `TabView` / `CustomTabBar` | `NavHost` + `NavigationBar` | 2 |
| `NavigationStack` / `Router` | `NavHost` + `rememberNavController` | 3 |
| `Picker` (wheel/menu) | `DropdownMenu` / `SingleChoiceSegmentedButtonRow` | 4 |
| `Toggle` | `Switch` | 2 |
| `.navigationTitle`/toolbar | `TopAppBar` | — |
| `Button` styles | `Button`/`FilledTonalButton`/`IconButton` | all |
| `GeometryReader` | `BoxWithConstraints` | — |
| `Canvas` + `Path` | `androidx.compose.foundation.Canvas`+`drawPath` (already `MnBreathing`) | 1 |
| `withAnimation`/`TimelineView` | `animate*AsState`/`Animatable`/`rememberInfiniteTransition` (done) | 6 |
| `.task`/`.onAppear` | `LaunchedEffect` | — |
| `@Observable` VM | Kotlin state holder: `remember{mutableStateOf}` / `ViewModel`+`StateFlow` (plan: mirror) | — |
| `@Environment(Type.self)` | params / `CompositionLocal` | — |
| `UIImpactFeedbackGenerator` | `HapticFeedback`/`LocalHapticFeedback` (Compose) | 1 (`MeditateSelectView:113`) |

## 3. ThemeManager → MaterialTheme

Android `MnTheme.kt` currently = **darkZen only** (iOS default) + only tokens
onboarding uses. No theme picker on Android.

| `MainTheme` token | `MnTheme` (exists) | M3 target |
|---|---|---|
| `mainBackground` (gradient/solid) | `background=0xFF0F1424` | `colorScheme.background` |
| `textPrimary` | `textPrimary` | `onBackground` |
| `textSecondary` | `textSecondary` | `onSurfaceVariant` |
| `iconPrimary` | `iconPrimary` | `onBackground` |
| `toolbarBackground` | — | `surfaceVariant` |
| `dividerColor` | `divider` | `outlineVariant` |
| `editorBackground` | — | `surface` |
| `accentButton`/`accentColor` | `accentButton=0xFFB052B5` | `primary` |
| `buttonText` | `buttonText` | `onPrimary` |
| `streakSuccess`/`streakActiveNote` | ✓ | custom (keep `MnTheme`) |
| `streakActiveMeditation`/`streakMuted`/`streakCellBackground`/`streakIndicator`/`danger` | — | custom `MnTheme` |
| `colorScheme` light/dark | — | `darkColorScheme`/`lightColorScheme` |
| `breathingPhaseColor(_:)` | `MnBreathing` | keep |

M3 has no extended palette → streak/breathing custom colors stay in `MnTheme`
(CompositionLocal if per-theme). Multi-theme = 5 `MnTheme` variants or token table;
add with theme picker, not before.

## 4. Navigation mapping

iOS `Router` (`Destination`: `.tab/.push/.sheet/.fullScreen`, tab-hierarchy,
`DeepLinkParser`) → Navigation Compose (already in `MainActivity.MnNav`):

- `TabDestination` → top-level routes / `NavigationBar` items (`home`,`notes`,`meditations`)
- `PushDestination` → `navController.navigate(route)`; keep route names mirroring enum
  (`noteDetails/{id}`, `meditation/{id}`, `settings`, `streakDetail`)
- `SheetDestination` → `ModalBottomSheet` boolean/state (not nav route) — matches iOS semantics
- `FullScreenDestination` → `composable` w/ no-anim or full `Dialog`
- deep links → `NavHost` `deepLinks=`

Use what exists: `NavHost`+string routes now; upgrade to typed routes when >2 args.
Do **not** invent iOS Router hierarchy in Compose.

## 5. Recommended porting order (no missing JNI first)

1. **Tab shell** `RootContainer`/`CustomTabBar` → `NavigationBar`+nested `NavHost` (no JNI)
2. **MainView** streak header (StreakActivityStore ✓)
3. **NoteMenu** (NoteDataSource ✓) — *bus wiring done: the Kotlin `DomainEventBus`
   replaced the manual reload fallback*
4. **NoteEditor** (NoteManager ✓; AI features degrade to `AIDraftManagerStub`)
5. **TimeMeditationSheet** + **MeditationCompletion** (Core-only)
6. **Settings** (ReminderSettings ✓; theme picker + sound/animation prefs)
7. **StreakDetail/Insights** (StreakActivityStore ✓; engine blocked)
8. **AI-dependent last:** `AIDraftSettingsView`, `NoteInsights`, `SoundSettingsSheet`
   (SoundPlayer/ExoPlayer, AICore — Фаза 3)

## 6. Risks

- **Core `DomainEventBus` is not callable from Kotlin** (jextract drops the
  `AsyncStream` API and the `DomainEvent` enum) → the Android screens use the
  Kotlin transport in `domain/events/DomainEventBus.kt`; the Core bus stays
  iOS-only unless someone pays for the JNI-safe rewrite.
- **iOS-only APIs:** `UIImpactFeedbackGenerator` (haptics), `verticalSizeClass`
  landscape branches, `NavigationStack` sizing.
- **Custom drawing:** `DarkZenStarfield` (Canvas, stars stable via `onAppear` — mirror
  with `remember`), `BreathingPathView`/`ConcentricRing` (partly done in `MnBreathing`).
- **Animations:** `withAnimation` (6), breathing `TimelineView` — need `Animatable`
  equivalence; verified approach exists.
- **Sound/haptics/AI:** AVFoundation→ExoPlayer, CoreHaptics→Vibrator,
  FoundationModels→AICore/ML Kit — none done.
- **No `strings.xml`** (only `themes.xml`) → port hardcoded Swift strings into resources.
- **No `@Preview`** in Android UI yet.
- **`StreakInsightEngine` JNI blocked** (plan Фаза 5 partial).
