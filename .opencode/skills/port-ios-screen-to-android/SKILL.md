---
name: port-ios-screen-to-android
description: >
  Port a SwiftUI screen of MeditateAndNote to Android (Jetpack Compose + Material 3).
  Use when asked to port, migrate or recreate an iOS screen/view on Android.
  Do NOT use for editing iOS-only code or for new Android screens with no iOS source.
---

# Port iOS screen → Android (Compose + M3)

Recreate one iOS screen in `Android/app/src/main/java/com/mn/android/ui/`. UI is
**never shared** — SwiftUI and Compose are rebuilt independently. Business logic
stays in Swift Core and crosses via JNI (see `ANDROID_PORT_PLAN.md`); the Compose
layer only holds screen state and calls generated `com.mn.core.*` types.

Reference data (read before starting):
- `references/screens-and-order.md` — screen→ViewModel→Store→JNI status table, recommended porting order.
- `references/component-mapping.md` — SwiftUI→Compose/M3 component table.
- `references/theme-mapping.md` — `MainTheme`/`ThemeManager` → `MnTheme`/`MaterialTheme` token table.

## Workflow

1. **Analyze** the iOS screen: find the `View` + its `ViewModel`, list every
   manager/store it touches, and check each against `references/screens-and-order.md`
   for a JNI implementation on Android. If a dependency is missing (✗), say so and
   stop — do not stub it silently.
2. **Plan** (short): destination route, state holder choice (`remember`/`mutableStateOf`
   vs `ViewModel`+`StateFlow`), which Core types are called, which components/theme
   tokens map. **Present and wait for OK.** No code before OK.
3. **Implement** in `Android/app/src/main/java/com/mn/android/ui/<feature>/`.
4. **Verify**: `./gradlew assembleDebug` in `Android/`, read the output, report the
   command + result.

## Navigation rules

Uses Navigation Compose (`NavHost` + `rememberNavController`), already wired in
`MainActivity.MnNav`. Map iOS `Router.Destination` cases directly, reusing the same
destination names as routes:

- `.tab` → top-level route / `NavigationBar` item (`home`, `notes`, `meditations`).
- `.push` → `navController.navigate("route")`; keep param naming from the enum
  (`noteDetails/{id}`, `meditation/{id}`, `settings`, `streakDetail`).
- `.sheet` → `ModalBottomSheet` boolean state, **not** a nav route (matches iOS).
- `.fullScreen` → `composable` with no shared-element animation, or full `Dialog`.
- Deep links (`DeepLinkParser`) → `NavHost` `deepLinks=`.

Do **not** reproduce the iOS Router hierarchy (parent/child routers, `isActive`) in
Compose; `NavHost` owns the back stack. Route strings live in the graph in `MainActivity`.

## Per-screen checklist

- [ ] **State**: mirror the iOS `@Observable` ViewModel as a Kotlin state holder.
      Use `remember { mutableStateOf(...) }` / `remember` for state that dies with the
      screen; switch to a `ViewModel` + `StateFlow` only when state must survive
      recomposition. Core is **not** a live state source — it is read/written on demand.
- [ ] **Actions**: every ViewModel method → a lambda/callback; call generated
      `com.mn.core.*` (Swift) types only through the JNI wrappers already in
      `Android/.../data/`. No business rules in the composable.
- [ ] **JNI dependencies**: each store/manager the screen needs has a Kotlin impl
      (`NoteBlobStore`, `StreakSnapshotStore`, `SessionBlobStore`, `OnboardingStore`,
      `MeditationSelection`, `SharedPrefsReminderSettingsStore`) or a generated
      `com.mn.core.*` type. Missing → block and report, don't fake.
- [ ] **Strings**: no hardcoded user-visible strings — add to
      `Android/app/src/main/res/values/strings.xml` (create it; only `themes.xml` exists).
- [ ] **Previews**: add a `@Preview` composable for the screen; none exist yet.
- [ ] **Theme**: use `MnTheme` / `MaterialTheme` tokens — no literal `Color(...)`.

## Rules

- **Material 3 only** — no Material 2 imports, no third-party UI kit.
- **No hardcoded colors in composables**: pull from `MnTheme` or `MaterialTheme.colorScheme`.
- **Business logic stays in Core via JNI** — composables and state holders orchestrate
  only; validation/invariants live in the Swift entity/Manager (see `ddd-audit`).
- **Never parse Core-owned payloads in Kotlin.** Blob/JSON columns (`NoteBlobStore`,
  `SessionBlobStore`, streak snapshot) are opaque to Kotlin by design. If a screen needs
  decoded data there is no read path yet → **block and report**; do not decode the
  payload in Kotlin and do not add a parallel Kotlin DataSource. The fix is a Swift
  adapter / `@_cdecl` entry (touches Swift → needs OK), or regenerating the missing
  thunk (`Scripts/build-android.sh --jextract`).
- **Follow the existing per-domain Store pattern** — new persistence is a Kotlin
  implementation of an existing Core protocol (e.g. `<X>Store` protocol + Kotlin impl +
  `Kotlin<X>Store` Swift adapter), never a new parallel mechanism.
- **Do not touch Swift code.** The only exception is adding the Swift adapter that
  belongs to a new Store, and that follows the `Kotlin<X>Store` pattern from the plan.
- Load `android-jetpack-compose-m3` for M3 component specifics while implementing.

## Definition of done

1. Load `superpowers/verification-before-completion`.
2. Run `./gradlew assembleDebug` in `Android/` and **read its output**.
3. Report claims with the exact command and its actual result. Never say "builds" /
   "done" without the output.
4. iOS is untouched (no Swift diff except an allowed Store adapter).
