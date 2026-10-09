# Theme mapping — `MainTheme` / `ThemeManager` → `MnTheme` / `MaterialTheme`

iOS `ThemeManager` (`@Observable`, 5 themes, persisted in UserDefaults under
`selectedMainTheme`) and `MainTheme` (token `@ViewBuilder`s) are **not ported**.
Android has `MnTheme.kt`, currently `darkZen` only (iOS default), with only the
tokens the onboarding flow reads. No theme picker exists on Android yet.

Rules: use `MnTheme` for custom tokens and `MaterialTheme.colorScheme` for standard
surfaces. No literal `Color(...)` in composables. Add a token only when a real screen
reads it — do not pre-translate all 5 themes.

| `MainTheme` token | `MnTheme` today | M3 target |
|---|---|---|
| `mainBackground` (gradient / solid) | `background = 0xFF0F1424` | `colorScheme.background` |
| `textPrimary` | `textPrimary` | `onBackground` |
| `textSecondary` | `textSecondary` | `onSurfaceVariant` |
| `iconPrimary` | `iconPrimary` | `onBackground` |
| `toolbarBackground` | — | `surfaceVariant` |
| `dividerColor` | `divider` | `outlineVariant` |
| `editorBackground` | — | `surface` |
| `accentButton` / `accentColor` | `accentButton = 0xFFB052B5` | `primary` |
| `buttonText` | `buttonText` | `onPrimary` |
| `streakSuccess` | ✓ | custom (keep in `MnTheme`) |
| `streakActiveNote` | ✓ | custom |
| `streakActiveMeditation` | — | custom |
| `streakMuted` | — | custom |
| `streakCellBackground` | `cardBackground` | custom |
| `streakIndicator` | — | custom |
| `danger` | — | `colorScheme.error` (or custom) |
| `colorScheme` (light/dark) | — | `darkColorScheme` / `lightColorScheme` |
| `breathingPhaseColor(_:)` | `MnBreathing` | keep in `MnBreathing` |

## Notes

- M3 has no extended palette: streak/breathing colors stay as `MnTheme` fields.
  If/when per-theme values are needed, expose `MnTheme` via a `CompositionLocal`,
  don't scatter `if (theme == ...)` in composables.
- `DarkZenStarfield` (iOS `Canvas`, stars generated once in `onAppear`) → Compose
  `Canvas` with `remember { List(40) { ... } }` so the star positions are stable.
- `ThemeManager` reads/writes UserDefaults (`selectedMainTheme`). If the theme picker
  is ported, mirror the same key in `SharedPreferences` (see `OnboardingStore` pattern).
- Theme picker UI (`SettingsView` theme list) is currently un-ported; add `MnTheme`
  variants in the same change, not before.
