# UI parity: iOS → Android

Side-by-side captures used while re-porting the Android presentation layer to match the
iOS app. iOS is the reference; Android is the after state.

- `ios/` — 21 screenshots, iPhone, Dark Zen theme (default on both platforms).
- `android/` — same screens on emulator `Medium_Phone_API_37.0` (1080×2400), same numbering.

No "before" captures were kept — the earlier Android screens were overwritten in place
while fixing them. The deltas that mattered are listed below.

## Screen map

| # | Screen | iOS | Android | Notes |
|---|--------|-----|---------|-------|
| 01 | Home | `01-home.png`, `01b-home-active.png` | `01-home.png` | |
| 02 | Settings | `02-settings.png`, `02-settings-scrolled.png` | `02-settings.png`, `02-settings-scrolled{,2,3}.png` | Android split across 4 scroll positions |
| 03 | Meditate select | `03-meditate-select.png` | `03-meditate-select.png`, `03-meditate-selected.png` | |
| 04 | Duration wheel | `04-duration-sheet.png` | `04-duration-sheet.png` | |
| 05 | Breathing session | `05-breathing.png` | `05-breathing.png`, `05b-breathing-rings.png` | Android also captures the Rings style, which has no iOS reference shot |
| 06 | Completion | `06-completion.png` | `06-completion.png` | recaptured — the old Android shot showed Home |
| 07 | Note editor | `07-note-editor.png` | `07-note-editor.png` | |
| 08 | Notes list | `08-notes.png` | `08-notes.png` | |
| 09 | Streak detail | `09-streak-detail.png` … `09d-streak-detail-bottom.png` | `09-streak-detail.png`, `09b`…`09d` | |
| 10 | Streak day sheet | `10-streak-day-sheet.png` | `10-streak-day-sheet.png` | |
| 11 | Paywall | `11-paywall.png` | — | no IAP on Android |
| 12 | Onboarding 1–3 | `12-onboarding-{1,2,3}.png` | `12-onboarding-{1,2,3}.png` | |
| 13 | Sound sheet | `13-sound-sheet.png` | `13-sound-sheet.png` | visual only, see gaps |
| 14 | Notes list — AI insights | — | `14-notes-insights.png` | Android-only section (v1 insights, no LLM); iOS reference: `NoteInsightsSection` in the notes list |
| 15 | Note editor — AI draft bar | — | `15-note-editor-ai-draft.png` | Android-only shot (remote provider, mock answer); iOS reference: `aiDraftBar` in `NoteEditorView` |
| 16 | Note editor — restored draft | — | `16-note-editor-draft-restored.png` | the same draft after leaving and reopening the note: the session is stored, no new generation |
| 17 | Note editor — AI draft on a real device | — | `17-note-editor-ai-draft-device.png` | Samsung SM-A245F, Android 16: the same bar against a mock provider reached over `adb reverse` |
| 18 | Note editor — AI draft, live provider | — | `18-note-editor-ai-draft-live-provider.png` | the deployed Vercel proxy answering with the real Groq (`openai/gpt-oss-120b`) |
| 19 | Note editor — AI draft, live provider on a device | — | `19-note-editor-ai-draft-live-provider-device.png` | Samsung SM-A245F against the same hosted proxy |
| 20 | Note editor — AI draft, public provider | — | `20-note-editor-ai-draft-public-provider.png` | the same, after the deployment protection came off — the endpoint answers anonymous requests |

## What was fixed

**Theme / color**
- Accent token was `#B052B5`; iOS renders `#DB34F2` in dark mode (sampled from the
  `Start Meditation` button). `ACCENT_DARK` fixed.
- Named-color constants (`GREEN`, `BLUE`, `PURPLE`, …) had used web named-color values.
  Replaced with Apple system values: `#34C759`, `#007AFF`, `#AF52DE`, `#FF9500`, `#FF3B30`,
  plus alpha variants.
- Breathing phase colors split into light/dark pairs with the iOS alpha values
  (`inhale #64D2FF @ 90%`, `hold-after-inhale #0A84FF`, `exhale #BF5AF2`,
  `hold-after-exhale #5E5CE6`; light equivalents `#008CA6`/`#007AFF`/`#AF52DE`/`#5856D6`).

**Meditation animation**
- The engine publishes `phaseProgress` at 10 Hz (iOS: a 0.1 s `phaseTimer`; Android: a
  100 ms `HandlerTicker`). iOS smooths those steps with SwiftUI's implicit animation,
  Android drew them raw — the path ball jumped ten times a second and the rings never
  rippled.
- Path view: the ball now glides with iOS's `.animation(.linear(duration: 0.1),
  value: phaseProgress)`. Only the ball is interpolated — SwiftUI cannot interpolate a
  `Path`, so the progress line stays stepped on both platforms.
- Rings view: one `Animatable` per ring, eased over 80 % of the phase with a 0.2 s
  stagger per ring — iOS `ConcentricRing`'s
  `.easeInOut(duration: phase * 0.8).delay(index * 0.2)`. Verified on device: the outer
  rings trail the inner ones mid-phase.
- Rings view: the phase colour cross-fades over 0.3 s (iOS
  `.animation(.easeInOut(duration: 0.3), value: breathingColor)`).
- Path view: the ball takes the phase colour — iOS passes `ballColor: breathingColor`,
  Android used `streakIndicator` (orange).
- Phase index: Android derived it from the session `remaining`, which only moves at
  1 Hz, so it lagged the engine by up to a second and the ball drew on the previous
  segment. Now reads `engine.getCurrentPhaseIndex()` — the same value iOS reads.
- Progress capsule: iOS animates the fill with `.animation(.linear(duration: 0.3),
  value: progress)`; Android drew the raw progress, so the fill edge crept in steps.
- Home hero: iOS `MeditateThemeButtonStyle` scales the hero on press (0.92–0.95 per
  theme, plus a dim) with `.easeInOut(duration: 0.15)`. Android had no press state at
  all — `clickable` alone draws none. Measured on device: 564 px idle → 532 px pressed
  (0.943×, iOS darkZen's 0.94).
- Checked and left alone: the loader's breathing pulse (2.4 s reverse, matches), the
  weekday heatmap's staggered appear (300 ms + 50 ms per column, matches), the
  lifetime-patterns stagger (matches), and the countdown digit — iOS declares a
  `.scale.combined(with: .opacity)` transition, but the reference video shows the
  digits swapping instantly (flat size, flat brightness), so Android already matches.

**Small offsets (sweep of the reference pairs)**
- The "Settings" and "Add Note" capsules are 50 pt tall on iOS (a 40 pt text
  frame plus 5 pt padding) with a 1 pt `dividerColor` hairline and a 17 pt
  semibold (`.headline`) label; Android had 44 dp, no hairline and
  `titleMedium` (16 sp medium). Both now 50 dp + 1 dp hairline + 17 sp semibold.
- Streak day cell: iOS draws `note.text` at 9 pt, Android drew the mapped
  Material glyph at 12 dp.
- Sound sheet: iOS uses the filled `speaker.wave.2.fill` / `speaker.fill` /
  `speaker.wave.3.fill`; Android used the outlined Material glyphs. The volume
  slider is SwiftUI's 4 pt line with a round white knob, not Material 3's 16 dp
  bar with a stop dot — the `track` slot now draws the thin line.
- Sound sheet label: "Sound Volume" is `.headline` (17 pt semibold) on iOS,
  `headlineSmall` (24 sp) on Android.
- Completion: the "Write a Note" button uses SF `square.and.pencil` (Material
  `EditNote`, not a bare pencil) and a 17 pt semibold label.
- Tab bar: iOS insets the capsule 6 pt vertically, Android 8 dp.

**Strings**
- Every user-visible literal in the presentation layer now comes from
  `strings.xml`: the last 29 hardcoded ones (titles, "Close", "Skip", "Play sample",
  "Sound Volume", the section headings and the `%-format` numbers) moved into
  resources with format arguments.

**Components**
- Tab bar: floating capsule with a selection pill; icons `Article` / `Home` / `Eco`.
- Meditate select re-ported: title is the selected meditation name, card layout, strings.
- Hero: the launch loader's glow is a radial gradient, not `Modifier.shadow` — Android
  tessellates a circle outline into a polygon, which drew an octagon behind the icon. The
  wind glyph went 48dp → 56dp because Material's `Air` carries viewport padding and drew
  ~8dp smaller than iOS's SF Symbol at the same nominal size (now 45.7dp wide vs 46.7pt).
- Progress capsule was a Material `Button` that centred its fill — this produced a vertical
  stripe instead of a growing bar. Now a plain `Box` + `clickable` with the fill anchored
  `CenterStart`, colored by the current phase.
- Duration sheet: the iOS `CustomTopRoundedShape` dome (quad curve, `toolbarBackground`)
  is drawn behind the sheet; rows are 32dp with the centre row at 22sp against 18sp to
  read as a drum. Insets measured off iOS: pill 14dp, Start button 16dp. Transparent
  container and scrim so the wheel floats.
- Completion: no top bar and no close button, `CheckCircle`, 32sp "Well Done!",
  bottom-pinned actions.
- Notes: search field lost its magnifier and hairline borders; Add Note is a shadowed pill.
- Settings: circular bordered back button with centred title, segmented-control selection
  uses the grey toolbar background (not accent), slider thumbs are plain 22dp white circles.
- Streak detail: `CenterAlignedTopAppBar` with a bordered "Done" pill, recommendations
  collected into one card, grey range-picker selection.
- Onboarding / editor icons matched to the SF Symbols used on iOS.
- Sound: `SoundPlayer` is a native `SoundPool` over the seven bundled `res/raw` cues
  (no JNI needed), volume from `SoundSettings`. Verified on device: the sample button
  drives `CCodec` with `audio/raw`.

## Known gaps

- **Paywall / Pro locks** — no in-app purchase on Android; the entry points and lock
  badges are absent rather than dead.
- **AI draft bar** — iOS suggestions come from Foundation Models; the only provider
  Android could use is `DisabledAIDraftService`, so the sparkle entry point is hidden.
- **Note insights** — the premium insights panel (`NoteInsightsViewModel`) has no Android
  counterpart.
- **Note editor formatting toolbar** — iOS shows a `FloatingToolbar` (bold / italic /
  list) above the keyboard, but its three buttons are `Button(action: {})` — they do
  nothing. Not ported: dead UI on one side is not worth cloning.
- **Rings animation mode** — ported (5 rings, `120 + i*30` base, ×`1 + 0.3(i+1)`
  expansion, per-ring 0.2 s stagger, 0.3 s colour cross-fade) and captured in
  `05b-breathing-rings.png`. iOS gates Rings behind the Pro entitlement, so no iOS
  screenshot exists to diff against: the match rests on reading `ConcentricRing.swift`
  plus the Path mode, whose iOS reference video was recorded and compared frame by
  frame (iOS interpolates the ball every frame; Android now does too).
