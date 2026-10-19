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
| 06 | Completion | `06-completion.png` | `06-completion.png` | |
| 07 | Note editor | `07-note-editor.png` | `07-note-editor.png` | |
| 08 | Notes list | `08-notes.png` | `08-notes.png` | |
| 09 | Streak detail | `09-streak-detail.png` … `09d-streak-detail-bottom.png` | `09-streak-detail.png`, `09b`…`09d` | |
| 10 | Streak day sheet | `10-streak-day-sheet.png` | `10-streak-day-sheet.png` | |
| 11 | Paywall | `11-paywall.png` | — | no IAP on Android |
| 12 | Onboarding 1–3 | `12-onboarding-{1,2,3}.png` | `12-onboarding-{1,2,3}.png` | |
| 13 | Sound sheet | `13-sound-sheet.png` | `13-sound-sheet.png` | visual only, see gaps |

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
  is drawn behind the sheet; rows are 38dp with the centre row enlarged (24sp vs 18sp)
  to read as a drum, plus pluralized labels, a transparent container and scrim.
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
- **Rings animation mode** — ported (5 rings, `120 + i*30` base, ×`1 + 0.3(i+1)`
  expansion) and captured in `05b-breathing-rings.png`; there is no iOS reference
  screenshot to diff against, so the match rests on reading `ConcentricRing.swift`.
