# SwiftUI → Compose / Material 3 component mapping

Recurring components found in `MeditateAndNote/Views/` and their Compose/M3
equivalent. Counts are occurrences in the iOS Views layer.

| SwiftUI | Compose / M3 | iOS occurrences |
|---|---|---|
| `List` | `LazyColumn` | 1 |
| `ScrollView` | `Column` + `verticalScroll` / `LazyColumn` | many |
| `.sheet` | `ModalBottomSheet` (`rememberModalBottomSheetState`) | 4 |
| `.fullScreenCover` | full-screen `Dialog` or a `composable` with no animation | 1 |
| `.alert` / `confirmationDialog` | `AlertDialog` | 2 |
| `TabView` / `CustomTabBar` | `NavHost` + `NavigationBar` | 2 |
| `NavigationStack` / `Router` | `NavHost` + `rememberNavController` | 3 |
| `Picker` (wheel/menu) | `DropdownMenu` / `SingleChoiceSegmentedButtonRow` | 4 |
| `Toggle` | `Switch` | 2 |
| `.navigationTitle` / toolbar | `TopAppBar` | — |
| `Button` styles | `Button` / `FilledTonalButton` / `IconButton` | all |
| `GeometryReader` | `BoxWithConstraints` | — |
| `Canvas` + `Path` | `androidx.compose.foundation.Canvas` + `drawPath` (see `MnBreathing`) | 1 |
| `withAnimation` / `TimelineView` | `animate*AsState` / `Animatable` / `rememberInfiniteTransition` | 6 |
| `.task` / `.onAppear` | `LaunchedEffect` | — |
| `@Observable` ViewModel | Kotlin state holder: `remember { mutableStateOf }` / `ViewModel`+`StateFlow` | — |
| `@Environment(Type.self)` | function params / `CompositionLocal` | — |
| `UIImpactFeedbackGenerator` | `LocalHapticFeedback` / `HapticFeedback` | 1 (`MeditateSelectView:113`) |
| `.tint(_:)` | `contentColor` / `colors = ButtonDefaults...` | — |
| `Divider` | `HorizontalDivider` | — |

## Already-ported precedents (copy these, don't reinvent)

- Theme: `Android/app/src/main/java/com/mn/android/ui/theme/MnTheme.kt`
- Breathing animation (Canvas + Animatable): `.../ui/theme/MnBreathing.kt`
- Navigation graph: `MainActivity.MnNav`
- State-holder pattern: `.../ui/meditate/BreathingSessionViewModel.kt`, `MeditateSelectScreen.kt`
- Core-type mapping to UI model: `.../data/MeditationCatalog.kt` (`MeditationUi`)
