# MeditateAndNote

Native iOS (SwiftUI) app for guided meditation with breathing visuals and a short reflective journal — the two combine into a daily streak you're nudged to keep alive. All AI features run on-device via Apple Intelligence.

## Features

- **Guided meditations** — 6 built-in meditations across 5 categories (mindfulness, breathing, sleep, focus, relaxation), animated breathing UI (4-7-8, Box, 4-8, custom), sound cues, duration picker.
- **Journaling** — searchable notes list, rich note editor with floating toolbar.
- **Daily streak** — meditate **and** write a note on the same day to complete it. Insights engine surfaces weak days, break-risk, time-of-day patterns, weekday heatmap, milestones and more.
- **AI-assisted writing (iOS 26+, on-device)** — "Help me write" drafts and per-note AI summaries.
- **Premium (RevenueCat)** — "Pro" subscription gates 3 of 5 themes, the `rings` animation style, unlimited AI drafts (free tier: 5 lifetime) and note insights; paywall presented from a single shared presenter, `.subscriptionChanged` domain event re-evaluates entitlements at runtime (revoked → clamped back to free defaults).
- **Reminders** — configurable daily reminder with a 7-day notification horizon.
- **Theming** — 5 built-in themes (liquid glass, breathing, soft dawn, dark zen, obsidian) plus sound and animation settings.
- **Onboarding** — multi-page onboarding and deep-link navigation.

## Tech stack

Apple platform with one external dependency — RevenueCat (`purchases-ios-spm`, SPM):

- SwiftUI + `@Observable` (Observation framework), iOS 17.6+
- CoreData (programmatic model, no `.xcdatamodeld`)
- AVFoundation (sounds), UserNotifications (reminders), Security (Keychain)
- FoundationModels / Apple Intelligence on-device LLM (iOS 26+, optional)
- RevenueCat Purchases SDK (subscriptions; key injected via `Config/*.xcconfig` → `Info.plist`)

Shared domain logic lives in the local Swift package `Packages/MeditateAndNoteCore` (entities, value objects, engines, domain events) — it is also compiled for Android (`Packages/MeditateAndNoteCoreJNI` → Kotlin/Compose UI).

## Architecture

Domain-Driven Design with dependencies pointing inward:

```
Presentation (SwiftUI Views, ViewModels)
        ↓
Application (NoteManager, StreakTracker, InsightManager, ReminderManager, ...)
        ↓
Domain (Entities, Value Objects, DataSource/Store protocols)
        ↑
Infrastructure (Persistence/ — CoreData + UserDefaults implementations)
```

Conventions: per-domain `<X>DataSource`/`<X>Store` protocols with `CoreData`/`InMemory`/`UserDefaults` implementations, Managers split into read/write (`<X>Providable`/`<X>Manageable`) contracts, cross-cutting side effects routed through a domain-event bus, custom Router-based navigation instead of `NavigationStack` logic in views. See [ARCHITECTURE.md](ARCHITECTURE.md) for details.

## Getting started

Open `MeditateAndNote.xcodeproj` in Xcode 16+ and run the `MeditateAndNote` scheme on an iOS simulator. On-device AI features require iOS 26 and the Xcode 26 SDK and are skipped gracefully on older toolchains.

```bash
open MeditateAndNote.xcodeproj
```

To replay onboarding during development, add the `-showOnboarding` launch argument.

RevenueCat key comes from `Config/*.xcconfig` (`REVENUECAT_API_KEY`) → `Info.plist`; commit only the placeholder configs and keep `*.local.xcconfig` overrides out of git.

## Project layout

```
MeditateAndNote/
├── AppContainer/     DI root: lazy event Scopes + make<X>ViewModel() factories
├── Config/           xcconfig (RevenueCat key, build settings)
├── Navigation/       Router, destinations, deep links, onboarding, Config
├── Views/            SwiftUI views (Paywall, Settings, Theme, ...)
├── ViewModels/       @Observable view models
├── Services/         Domain services (notes, streak, meditation, AI, subscriptions, ...)
├── Persistence/      CoreData/UserDefaults data sources & stores
├── Extensions/
Packages/
├── MeditateAndNoteCore/       Shared Swift package: domain, engines, events
├── MeditateAndNoteCoreJNI/    swift-java wrappers for the Android build
Android/                        Kotlin/Compose UI over the shared Core (see ANDROID_PORT_PLAN.md)
server/                         Vercel function: the hosted AI provider (Groq behind an OpenAI-compatible proxy)
MeditateAndNoteTests/          Unit tests
MeditateAndNoteUITests/        UI tests
```

## Android

Port runs Swift Core + Kotlin/Compose UI (Swift SDK for Android + `swift-java` JNI). Progress, phases and measured JNI constraints: [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md), status analysis: [ANDROID_PORT_ANALYSIS.md](ANDROID_PORT_ANALYSIS.md). Android-side knowledge graph lives in `Android/graphify-out/`.

## AI provider

The apps speak the OpenAI chat-completions dialect (the wire protocol lives in the core package). On iOS the on-device model answers; on Android the provider is remote. `server/` is a Vercel function that proxies to Groq and keeps the provider key server-side — the apps need no key of their own. Details: [server/README.md](server/README.md).

## Tests

46 test files (44 unit + 2 UI) covering pure engines, managers, data sources, view models, navigation, AI and subscription services. Run from Xcode (`Cmd+U`) or:

```bash
xcodebuild test -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16'
```