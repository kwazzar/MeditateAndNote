# DDD Audit — Android Version

Scope: the Android app in this repo (`Android/app`). Swift owns the domain core
(`Packages/MeditateAndNoteCore`), so the Kotlin side stays a thin port:
domain ports in `domain/`, JNI adapters in `data/`, platform glue in
`infrastructure/`, Compose in `presentation/`.

Status: **all slices implemented and verified** — Notes, Meditation, Streak,
Books (+ Bookmarks), AI Draft, Note Insights, Settings/Theme, and the
Notes / Insights / Library / Reader / Settings ViewModels.

## Layer boundaries

| # | Issue | Resolution |
|---|-------|------------|
| 1 | **No repository abstraction per feature** | ✅ `domain/<feature>/<X>Repository` port per feature + `data/<feature>/Jni<X>Repository` adapter: `NoteRepository`, `MeditationRepository`, `StreakRepository`, `BookRepository`, `BookmarkRepository`, `AIDraftRepository`, `NoteInsightsRepository`. The subscription domain keeps its own ports. |
| 2 | **UI depends on `data` / `infrastructure`** | ✅ verified by grep: no file under `presentation/` imports `com.mn.android.data` or `com.mn.android.infrastructure`. |
| 3 | **No DI root** | ✅ `application/container/AppContainer.kt` — factory methods (`makeNoteEditorViewModel()`, `makeLibraryViewModel()`, `makeReaderViewModel()`, `makeSettingsViewModel()`, …) and getters for every port. |
| 4 | **No typed operation errors** | ✅ `sealed class <X>Error(cause: Throwable?) : Exception(cause)` per domain: `NoteError`, `MeditationError`, `BookOperationError`, `AIDraftError`. Streak intentionally has none. |
| 5 | **JVM-blocking JNI calls on the main thread** | ✅ `data/IoResult.kt` — `ioResult(wrap) { … }` moves every call to `Dispatchers.IO` and rethrows `CancellationException`. |

## Domain model

| # | Issue | Resolution |
|---|-------|------------|
| 6 | **Primitive obsession** | ✅ value objects: `NoteId`, `BookId`, `BookmarkId`, `MeditationId`; `ReminderSettings`, `NoteInsight`, `BookSummary`, `ReadingPosition`, `AnimationStyle`. |
| 7 | **JNI bridges are `object` singletons** | ✅ every feature now depends on a port, so the fakes in `src/sharedTest/` replace them in tests. |
| 8 | **Domain event bus is lossy (`DROP_OLDEST`)** | ⚠️ still open: acceptable for invalidation, but entitlement events (`SubscriptionChanged`) want replay or a `StateFlow`. |
| 9 | **Swift core types reach the ViewModel** | ⚠️ accepted: `BreathingSessionViewModel` drives `MeditationSessionEngine` (the session *controller*, not a data source); the data path sits behind `MeditationRepository`. |

## Layout

```
domain/<feature>/     ports + value objects (no android.*, no data, no infrastructure)
data/<feature>/       Jni<X>Repository adapters + IoResult
data/                 the JNI bridges themselves (unchanged Swift entry points)
infrastructure/       platform glue: preferences, notifications, sound, Keystore
presentation/         Compose screens + ViewModels (depend on domain ports only)
src/sharedTest/       fakes + repository contracts, shared by unit and device tests
```

## Tests

Every port has a fake in `src/sharedTest/`, a contract test that the fake
satisfies, a JVM test of the fake, and a device test that runs the real JNI
adapter against the same contract.

| Suite | Count |
|-------|-------|
| JVM unit tests (`testDebugUnitTest`) | **65, 0 failures** |
| On-device tests (`connectedDebugAndroidTest`, emulator API 37) | **104, 0 failures, 0 skipped** |

## Verification (run on this machine)

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk
export ANDROID_HOME=$HOME/Library/Android/sdk
cd Android
./gradlew :app:assembleDebug             # BUILD SUCCESSFUL
./gradlew :app:testDebugUnitTest        # 65 tests, 0 failures
./gradlew :app:connectedDebugAndroidTest # 104 tests, 0 failures, 0 skipped
```

The on-device run needs the local (gitignored) Firebase file
`Android/app/google-services.json`, and the iOS build needs
`MeditateAndNote/Resources/GoogleService-Info.plist` — both are listed in the
root README.
