# MeditateAndNote

Native iOS (SwiftUI) app for guided meditation with breathing visuals and a short reflective journal — the two combine into a daily streak you're nudged to keep alive. All AI features run on-device via Apple Intelligence.

## Features

- **Guided meditations** — 6 built-in meditations across 5 categories (mindfulness, breathing, sleep, focus, relaxation), animated breathing UI (4-7-8, Box, 4-8, custom), sound cues, duration picker.
- **Journaling** — searchable notes list, rich note editor with floating toolbar.
- **Daily streak** — meditate **and** write a note on the same day to complete it. Insights engine surfaces weak days, break-risk, time-of-day patterns, weekday heatmap, milestones and more.
- **AI-assisted writing (iOS 26+, on-device)** — "Help me write" drafts and per-note AI summaries.
- **Reminders** — configurable daily reminder with a 7-day notification horizon.
- **Theming** — 5 built-in themes (liquid glass, breathing, soft dawn, dark zen, obsidian) plus sound and animation settings.
- **Onboarding** — multi-page onboarding and deep-link navigation.

## Tech stack

Pure Apple platform — **zero external dependencies**:

- SwiftUI + `@Observable` (Observation framework), iOS 17.6+
- CoreData (programmatic model, no `.xcdatamodeld`)
- AVFoundation (sounds), UserNotifications (reminders), Security (Keychain)
- FoundationModels / Apple Intelligence on-device LLM (iOS 26+, optional)

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

## Project layout

```
MeditateAndNote/
├── AppContainer/     DI root (make<X>ViewModel() factories)
├── Models/           Domain entities, value objects, pure engines
├── Navigation/       Router, destinations, deep links, onboarding
├── Views/            SwiftUI views
├── ViewModels/       @Observable view models
├── Services/         Domain services (notes, streak, meditation, AI, ...)
├── Persistence/      CoreData/UserDefaults data sources & stores
└── MeditateAndNoteTests/
```

## Tests

33 test files covering pure engines, managers, data sources, view models, navigation and AI services. Run from Xcode (`Cmd+U`) or:

```bash
xcodebuild test -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16'
```