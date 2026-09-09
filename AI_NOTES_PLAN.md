# AI Notes — Implementation Plan

## Overview

Roadmap для додавання AI-підсилення до нотаток у MeditateAndNote. Відповідає DDD-архітектурі проєкту (Domain → Infrastructure → Application → Presentation) і повторює існуючий патерн `<X>DataSource` / `<X>Manager` з розділенням на `Providable` / `Manageable`.

| Sprint | Theme | Deliverable | LOC est. | Risk |
|--------|-------|-------------|----------|------|
| 1 | Foundation | Variant A MVP (Foundation Models) | ~800 | M |
| 2 | Resilience | A + Remote fallback + telemetry | ~400 | L |
| 3 | Enhancement | Variant B (Insights) on top of A | ~500 | M |
| 4 | Differentiation | Variant C (Voice) OR D (Semantic Search) | ~700–900 | H |

**Жодних SPM dependencies** — все через platform frameworks (`FoundationModels`, `Speech`, `NaturalLanguage`) = $0 marginal cost, zero supply chain risk.

---

## Sprint 1 — Smart Prompt MVP (Foundation Models)

**Status: ✅ DONE** (`48b35b8`, `df4e4a7` — AIDraftManager, Foundation Models service, in-flight guard, orphan cleanup).

**Goal:** Працюючий AI assistant у note editor через on-device Apple Foundation Models (iOS 26+).

### Architecture (DDD-compliant)

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation:  NoteAIDraftViewModel + NoteAIDraftSheet     │
│   depends on: any AIDraftProvidable & AIDraftManageable     │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│ Application:  AIDraftManager (actor)                         │
│   - orchestrates AIDraftService                             │
│   - publishes DomainEvent.draftGenerated                    │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│ Domain:  AIDraftSession (aggregate)                          │
│   - AIPrompt, AISuggestion, NoteAIDraftError                 │
│   - invariants: max 5 suggestions, immutable after complete │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│ Infrastructure:  AIDraftService protocol                     │
│   - FoundationModelsDraftService (iOS 26+)                  │
│   - DisabledDraftService (graceful fallback)                │
└─────────────────────────────────────────────────────────────┘
```

### Tasks

**Domain layer (zero external deps):**
- `Models/AI/AIPrompt.swift` — value object (instructions + context NoteID)
- `Models/AI/AISuggestion.swift` — value object (id + text + rationale)
- `Models/AI/AIDraftSession.swift` — aggregate root
  - invariants: max 5 suggestions per session
  - state machine: `.idle` → `.generating` → `.ready(suggestions)` → `.failed(error)`
- `Models/AI/NoteAIDraftError.swift` — `.noContext`, `.rateLimited`, `.providerUnavailable`, `.emptyResponse`, `.contextTooLong`

**Infrastructure layer:**
- `Services/AI/AIDraftService.swift` — protocol:
  ```swift
  protocol AIDraftService: Sendable {
      func suggest(_ prompt: AIPrompt) async throws -> [AISuggestion]
      var isAvailable: Bool { get async }
  }
  ```
- `Services/AI/FoundationModelsDraftService.swift`:
  - uses `LanguageModelSession` from `FoundationModels`
  - system instructions: "You help with reflective journaling..."
  - guardrails: max 280 chars per suggestion
  - `isAvailable` checks `SystemLanguageModel.default.availability == .available`
- `Services/AI/DisabledDraftService.swift` — для unavailable devices
- `Services/AI/AIDraftServiceFactory.swift` — runtime selection

**Application layer:**
- `Services/AIDraftManager.swift` — actor:
  ```swift
  protocol AIDraftProvidable {
      func session(for noteID: NoteID) async -> AIDraftSession?
  }
  protocol AIDraftManageable {
      func startDraft(noteID: NoteID, prompt: String, context: NoteContent) async throws -> AIDraftSession
      func regenerate(noteID: NoteID) async throws -> AIDraftSession
      func cancel(noteID: NoteID)
  }
  ```
- `DomainEvents.swift` — add case `.aiDraftGenerated(noteID: NoteID, sessionID: UUID)`

**Presentation layer:**
- `ViewModels/NoteAIDraftViewModel.swift` — `@MainActor @Observable`
  - exposes `session`, `error`, `isGenerating`
  - actions: `start`, `regenerate`, `cancel`, `insert(suggestion:into:)`
- `Views/NoteEditor/NoteAIDraftSheet.swift` — SwiftUI sheet
  - prompt input field
  - "Generate" button
  - suggestions list з insert buttons
  - loading + error states
- `Views/NoteEditor/NoteEditorView.swift` — add "✨ Help me write" toolbar button

**DI wiring:**
- `AppContainer.swift`:
  - lazy `aiDraftService: any AIDraftService = AIDraftServiceFactory.make()`
  - lazy `aiDraftManager = AIDraftManager(service: aiDraftService)`
  - factory `makeNoteAIDraftViewModel(noteID: NoteID, currentContent: NoteContent)`

**Tests:**
- `MeditateAndNoteTests/AIPromptTests.swift` — value object validation
- `MeditateAndNoteTests/AIDraftSessionTests.swift` — invariants (max 5, state transitions)
- `MeditateAndNoteTests/AIDraftManagerTests.swift` — using `DisabledDraftService` + event spy
- `MeditateAndNoteTests/FoundationModelsDraftServiceTests.swift` — mockable via protocol

### Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| iOS 26 не widespread | Sprint 2 додає remote fallback; Sprint 1 має graceful "not available" UI |
| Apple Intelligence disabled by user | Check `SystemLanguageModel.default.availability` перед показом button |
| Foundation Models API changes | Ізольовано в `FoundationModelsDraftService` — заміна реалізації не торкається domain |
| Latency на першому виклику | Показати skeleton loader; cancelable task |

### Definition of Done

- Build passes, tests green
- `FoundationModelsDraftService` НЕ доступний у previews/tests (тільки `DisabledDraftService`)
- Domain files не імпортують `FoundationModels` / `SwiftUI`
- `AppContainer.makeNoteAIDraftViewModel()` factory існує
- Manual test on iOS 26 simulator: створити нотатку → "Help me write" → отримати suggestions → вставити одну

---

## Sprint 2 — Remote Fallback + Telemetry

**Status: ✅ DONE** (`af4a604` + `992b3fe` — telemetry store, settings UI, privacy manifest; `RemoteLLMDraftService` registered in project by S3 commit).

**Goal:** Працює на всіх пристроях iOS 17+; збираємо метрики для прийняття рішень по Sprint 4.

### Tasks

**Infrastructure:**
- `Services/AI/RemoteLLMDraftService.swift`:
  - configurable endpoint (OpenAI/Anthropic compatible)
  - API key з Keychain (`KeychainService` wrapper, якщо ще немає — створити)
  - request DTO: `{prompt: String, context: String, maxSuggestions: Int}`
  - response DTO: `{suggestions: [{text, rationale}]}`
  - retry policy: 3x exponential backoff
- `Services/AI/AIDraftServiceFactory.swift` — extend:
  ```swift
  if #available(iOS 26, *), foundationModelsAvailable {
      return FoundationModelsDraftService()
  } else if remoteAPIEnabled {
      return RemoteLLMDraftService(...)
  } else {
      return DisabledDraftService()
  }
  ```

**Settings UI:**
- `Models/AI/AIDraftSettings.swift` — value object
- `Views/Settings/AIDraftSettingsView.swift`:
  - toggle: "Use remote AI when on-device unavailable"
  - API key input (secure field → Keychain)
  - privacy notice

**Telemetry (privacy-preserving):**
- `Services/Telemetry/AIDraftMetrics.swift`:
  - events: `draft_started`, `draft_completed`, `draft_failed`, `suggestion_inserted`, `suggestion_rejected`
  - NO content captured — тільки counts + latency + error type
- `Services/Telemetry/MetricsRecorder.swift` — protocol + CoreData impl
- `DomainEvents.swift` — додати `.aiDraftMetric(event: AIDraftMetric)`

**A/B testing hook:**
- `Services/AI/DraftVariant.swift` — `.foundation` / `.remote` / `.disabled`
- Persist user preference в `AIDraftSettings`

**Tests:**
- `RemoteLLMDraftServiceTests.swift` — URLProtocol mocking
- `AIDraftServiceFactoryTests.swift` — runtime selection logic
- `KeychainServiceTests.swift`

### Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| API cost runaway | Hard cap: 5 generations/day per user, configurable |
| Privacy concerns | Default OFF для remote; opt-in тільки через Settings з disclaimer |
| Keychain handling | Використати існуючий патерн, якщо є; або створити простий wrapper |
| App Store rejection | Disclose AI-генерований контент + remote API в privacy labels |

### Definition of Done

- На iOS 17/18 пристроях: працює через remote API
- Telemetry events recorded in CoreData
- Settings screen дозволяє toggle remote fallback
- Privacy disclosure оновлено
- Manual test: вимкнути Foundation Models в simulator → fallback працює

---

## Sprint 3 — AI Insights (Variant B)

**Status: ✅ DONE** (2026-09-09, `992b3fe` + `6ea72bb`; 23 new tests, full suite 423 green; manual QA on iOS 26.5 sim passed — seeded notes produce themed insights end-to-end through Foundation Models).

**Goal:** Background аналіз колекції нотаток, поверх існуючих `DomainEvent`s.

### Architecture

```
NoteManager publishes .noteCreated / .noteUpdated / .noteDeleted
  → AIDraftManager (consumes bus AsyncStream) → debounce 30s → triggers NoteAnalyzer
    → NoteInsight aggregate (themes, summary, suggestedTags)
      → NoteInsightManager publishes .noteInsightsUpdated
        → NoteMenuViewModel (for await) → updates insights section
```

### Tasks

**Domain:**
- `Models/AI/NoteTheme.swift` — value object (label + relevance 0...1)
- `Models/AI/NoteInsight.swift` — entity:
  ```swift
  struct NoteInsight {
      let noteID: NoteID
      let themes: [NoteTheme]
      let summary: String
      let suggestedTags: [String]
      let generatedAt: Date
  }
  ```
- `Models/AI/NoteInsightsCollection.swift` — aggregate з invariant: max 1 insight per note
- `Models/AI/NoteAnalysisError.swift` — `.insufficientData`, `.providerUnavailable`

**Infrastructure:**
- `Services/AI/NoteAnalyzer.swift` — protocol:
  ```swift
  protocol NoteAnalyzer: Sendable {
      func analyze(notes: [Note]) async throws -> [NoteInsight]
      var isAvailable: Bool { get async }
  }
  ```
- `Services/AI/FoundationModelsNoteAnalyzer.swift` — перевикористовує Foundation Models
- `Persistence/CoreDataNoteInsightStore.swift` — per-domain pattern
- `Models/AI/NoteInsightStore.swift` — protocol (`fetchAll`, `fetch(noteID:)`, `save`, `delete`)

**Application:**
- `Services/NoteInsightManager.swift`:
  - consumes `.noteCreated`, `.noteUpdated`, `.noteDeleted` via bus `AsyncStream`
  - debounces 30s, max once per minute
  - `NoteInsightProvidable` (read) + `NoteInsightManageable` (refresh)
  - publishes `.noteInsightsUpdated`

**Presentation:**
- `ViewModels/NoteInsightsViewModel.swift`
- `Views/NoteMenu/NoteInsightsSection.swift` — collapsible section в NoteMenu
- `NoteMenuViewModel.swift` — integrate insights section

**DI:**
- `AppContainer.makeNoteInsightsViewModel()` factory
- `AppContainer.handleEvent()` — додати case для `.noteInsightsUpdated` → insightManager

**Tests:**
- `NoteInsightTests.swift` — invariants
- `NoteInsightManagerTests.swift` — debouncing, event handling
- `CoreDataNoteInsightStoreTests.swift`

### Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Battery drain | Strict debounce (30s) + max 1 analysis per minute |
| Stale insights | Force refresh button in UI |
| Cold-start analysis | Lazy load; only analyze changed notes since last cache |
| Privacy | All local (Foundation Models); якщо remote — reuse Sprint 2 toggle |

### Definition of Done

- [x] Insights auto-refresh після створення/редагування нотаток (debounce 30s, throttle 1 pass/min — verified in logs)
- [x] NoteMenu показує collapsible insights section (`NoteInsightsSection`, top themes + 3 freshest + refresh button)
- [x] Manual test: створити 3 нотатки про подібну тему → отримати themes (sim: `calm`/`meditation`/`sleep` chips + summaries + `#tags`)
- [ ] Battery profile: < 5% per hour при background usage — **not measured**, open item

### Done — deviations from the plan & follow-ups

Deviations (all DDD-compliant, see `ddd-audit` 2026-09-09 — zero ❌):
- `.noteInsightsUpdated` carries `[NoteID]`, not the whole `NoteInsightsCollection` (subscribers reload from the store).
- `NoteAnalyzer.isAvailable` is **sync**, not async (all checks are cheap/local; avoids `await` warnings).
- `FoundationModelsNoteAnalyzer` falls back to `HeuristicNoteAnalyzer` per-note on any failure; heuristic is always available (iOS 17+, tests, previews).
- `NoteInsightsSection` loads on **every appear**, not only via events — background passes usually finish while the user is off-tab (found in manual QA).
- VMs are passed to views as `let`, not `@State` — `@State var vm: VM?` dropped the value (init got it, body saw `nil`); `let` always wins. Applies to any future `@Observable` VM passed via init.

Follow-ups (tech debt, non-blocking):
- `NoteInsight.maxSummaryLength` declared but unenforced — enforce or delete.
- `NoteInsightManager.refresh` batch is not atomic (partial batch on mid-loop failure; self-heals next pass).
- `AppContainer.init()` still public — production path uses `.shared` (see `6ea72bb`), but nothing stops a second production instance by hand.
- Double-`AppContainer` root cause (two live event loops/managers observed pre-fix) fixed by `.shared`; exact materialization path (defaultValue vs `@State` re-eval) not isolated — revisit if duplication symptoms return.
- Battery profiling (< 5%/h) still open; also re-check after the `.shared` fix (previously two managers ran double passes).

### First-touch verification (2026-09-09, real model on iPhone 17 sim)

- **Finding 1 — availability ≠ readiness.** `isAvailable == true`, but the first `suggest` threw `assetsUnavailable` within 1.4s on a fresh sim (system reports ready while assets download). So the very first "Help me write" can show an error state.
- **Finding 2 — cold start is minutes, not seconds.** First-ever model call blocked **165s** (asset download), vs the 1–3s assumed in Sprint 1 risks. Erasing the sim does not remove the runtime-cached asset, so this only hits true first launch.
- **Mitigation implemented** in `FoundationModelsAIDraftService.generate`: on `assetsUnavailable` / `concurrentRequests` — one bounded warmup retry after 10s, then regular error mapping. Hot path pays nothing; `rateLimited` is excluded (goes to `CompositeFallback` → remote instead). Classifier covered by `FoundationModelsDraftServiceTests` (7 tests).
- **Verified live:** draft e2e on warm sim (suggestions in 3.4s); analyzer e2e (2 insights). Sheet-UI flow, real-key remote, and battery profile remain manual-only.

---

## Sprint 4 — Differentiation (Variant C або D)

**Status: ⬜ NOT STARTED** — telemetry for the decision (`CDAIDraftMetric`: counts, latency, error kinds) is being collected since Sprint 2; decision pending real usage data. Current lean: **D (Semantic Search)** — lower risk, builds on existing search, iOS 17+ via NaturalLanguage.

**Рішення в кінці Sprint 3 на основі метрик з Sprint 2.**

### Decision criteria

| Metric | Favors C (Voice) | Favors D (Semantic Search) |
|--------|------------------|----------------------------|
| Users typing long notes (>500 chars) | yes | no |
| Users searching often | no | yes |
| Low retention on editor screen | yes | no |
| Search returns low-quality results | no | yes |
| Users on iOS 26+ | yes (both Foundation Models) | yes |
| Privacy-sensitive audience | yes (local) | yes (local) |

### If Variant C (Voice → Structured Note)

**Tasks:**
- `Services/Speech/TranscriptionService.swift` — protocol + `SpeechAnalyzerTranscriptionService`
- `Services/Speech/SpeechPermissionManager.swift` — AVAudioSession + SFSpeechRecognizer
- `Models/AI/VoiceDraftInput.swift` — value object (audioData + duration)
- `Services/AI/StructuredNoteComposer.swift` — uses Foundation Models для `{title, content, tags}` extraction
- `ViewModels/VoiceNoteViewModel.swift` — record → transcribe → compose → preview
- `Views/MeditateSelect/VoiceNoteButton.swift` — integration в post-meditation flow
- `AppContainer.makeVoiceNoteViewModel()` factory

**Risks:** +150 MB model asset після першого використання, permission UX

### If Variant D (Semantic Search)

**Tasks:**
- `Models/AI/NoteEmbedding.swift` — value object (`[Float]` vector + noteID)
- `Services/AI/EmbeddingService.swift` — protocol + `NLEmbeddingService` (NaturalLanguage)
- `Persistence/CoreDataNoteEmbeddingStore.swift` — stores vectors as Data
- `Models/AI/SemanticQuery.swift` — value object
- `Services/NoteManager.swift` — extend `NoteProvidable`:
  ```swift
  func notes(matching semanticQuery: SemanticQuery) async -> [Note]
  ```
- `ViewModels/NoteMenuViewModel.swift` — toggle keyword/semantic search
- Sync: regenerate embedding при `.noteUpdated`

**Risks:** +50 MB embedding model, sync overhead при edits

---

## Cross-Sprint Concerns

### Privacy & App Store
- Оновлення `PrivacyInfo.xcprivacy` після Sprint 2 (remote API)
- Disclosure для AI-генерованого контенту
- On-device by default; opt-in для remote

### Documentation
- Оновити `ARCHITECTURE.md` після кожного спринту
- Додати `Services/AI/README.md` з architecture diagram

### Performance Budget
- AI sheet open: < 100ms
- First suggestion: < 3s (cold) / < 1s (warm)
- Background insights: < 5% battery/hour
- No regression в existing autosave latency (800ms target)

---

## Sprint Velocity Assumptions

| Sprint | Duration | LOC | Notes |
|--------|----------|-----|-------|
| 1 | 1.5 weeks | ~800 | Foundation Models навчання команди може зайняти 2 дні |
| 2 | 1 week | ~400 | Більшість work — settings UI + telemetry plumbing |
| 3 | 1 week | ~500 | Background scheduling нюанси |
| 4 | 1.5 weeks | ~700–900 | Залежить від C/D |

**Total**: ~5–6 weeks для повної AI integration.

---

## Vulnerable Spots & Risk Audit

### 1. Deployment Target Conflict (CRITICAL)

**Факт:** `IPHONEOS_DEPLOYMENT_TARGET = 17.6` (`MeditateAndNote.xcodeproj/project.pbxproj:863,889,1043,1076`).

**Проблема:** Apple `FoundationModels` framework доступний з **iOS 26+**. Піднімати deployment target до 26 = відсікти всіх користувачів на 17/18/25.

**Можливі рішення:**
- **A)** Підняти deployment target до 26 → простий код, але значні user losses
- **B)** Залишити 17.6 + `if #available(iOS 26, *)` гейти (план передбачає це) → більше коду, але coverage зберігається
- **C)** Замість `FoundationModels` використовувати Core ML з custom моделлю (складніше, більше bundle size, але iOS 17+)

**Рекомендація:** Варіант **B** — поточна стратегія плану; вимагає ретельного feature gating у всіх entry points.

**Vulnerable spots у коді:**
- `AppContainer.makeAIDraftService()` — мусить повертати різний тип залежно від OS version
- `NoteEditorView.swift` — toolbar button visibility залежить від availability
- Tests — мусять використовувати `DisabledDraftService` на previews/sim < 26

---

### 2. DomainEvent Sum Type — Compile-time Trap (MEDIUM)

**Факт:** `DomainEvent` — closed enum (`MeditateAndNote/Services/DomainEvents.swift:14`), кожен subscriber має exhaustive switch (`StreakTracker.swift:269`, `CoreDataSessionStore.swift:99`).

**Проблема:** План пропонує додати нові cases:
```swift
case aiDraftGenerated(noteID: NoteID, sessionID: UUID)
case aiDraftMetric(event: AIDraftMetric)
case noteInsightsUpdated(NoteInsightsCollection)
```

Це **зламає compilation** у всіх існуючих subscribers (`StreakTracker.handle`, `CoreDataSessionStore.handle`, `StreakInsightManager.handle`, `NoteManagerTests.EventCapture`, `MeditationViewModelTests.MeditationEventCapture`).

**Vulnerable spots:**
- `StreakTracker.swift:269` — додати `.break` для нових cases
- `CoreDataSessionStore.swift:99` — додати `.break` для нових cases
- `StreakInsightManager.swift:131` — додати `.break`
- Всі test spies (`EventCapture`, `MeditationEventCapture`) — додати `.break`

**Можливі рішення:**
- **A)** Прийняти compile-time friction (безпечно, але торкається ~5-7 файлів щораз)
- **B)** Розділити `DomainEvent` на `NoteDomainEvent` + `MeditationDomainEvent` + `AIDomainEvent` через композицію — зменшує blast radius, але більше boilerplate

**Рекомендація:** Варіант **A** — проєкт свідомо обрав closed sum type як safety net (див. коментар `DomainEvents.swift:6-7`). Не варто розділяти без сильного приводу.

---

### 3. NoteEditorViewModel Integration Boundary (MEDIUM)

**Факт:** `NoteEditorViewModel` має власний debounce/autosave (800ms, `NoteEditorViewModel.swift:80-91`) і state machine `EditTarget` (`NoteEditorViewModel.swift:14-19`).

**Проблема:** План пропонує окремий `NoteAIDraftViewModel` + sheet, але не описує **як саме suggestions вставляються у note body**. Якщо просто мутувати `body: String` у `NoteEditorViewModel` — порушення DDD (бізнес-логіка у view model).

**Vulnerable spots:**
- `NoteEditorViewModel.swift:29` — `body: String` exposed mutatable
- Якщо `NoteAIDraftSheet` має reference до `NoteEditorViewModel` для `insert(suggestion:)` — tight coupling
- Якщо `NoteAIDraftViewModel` викликає `notes.update()` напряму — bypasses editor's dirty state

**Можливі рішення:**
- **A)** `NoteAIDraftViewModel` повертає `NoteContent` через callback/closure → `NoteEditorViewModel.applyDraft(content:)` мутує title/body + ставить target в `.loaded`
- **B)** AI sheet має `@Binding` до `body` → менш чисто, але простіше
- **C)** Suggestions вставляються як `note.content = suggestion.text` через `NoteManageable.update()` — bypasses UI

**Рекомендація:** Варіант **A** — callback pattern. Додати у план:
```swift
// NoteAIDraftViewModel output:
var onInsert: ((NoteContent) -> Void)?

// NoteEditorViewModel:
func applyDraft(_ content: NoteContent) {
    body = content.rawValue
    onTextChanged() // trigger autosave
}
```

---

### 4. PrivacyManifest Missing (HIGH)

**Факт:** `MeditateAndNote/` не містить `PrivacyInfo.xcprivacy` (перевірено — тільки `Resources/Sounds`).

**Проблема:**
- Sprint 2 з remote API **обов'язково** потребує `NSPrivacyTracking`, `NSPrivacyCollectedUsageTypes`, `NSPrivacyAccessedAPITypes`
- Apple вимагає privacy manifest для всіх app submissions з 2024
- Без нього — App Store rejection

**Vulnerable spots:**
- Немає файлу `Resources/PrivacyInfo.xcprivacy`
- Немає документації про які user data збираються

**Рекомендація:** Додати у Sprint 2 як **блокер**, не optional:
```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        ...
    </dict>
</array>
```

---

### 5. AIDraftSession Lifecycle & Memory (MEDIUM)

**Факт:** План не описує **коли sessions видаляються з `AIDraftManager`**.

**Проблема:**
- `AIDraftManager` має `session(for noteID:)` — кеш росте необмежено
- Кожен edit нотатки створює нову session → memory leak
- При background → foreground немає cleanup policy

**Vulnerable spots:**
- `AIDraftManager.swift` — `private var sessions: [NoteID: AIDraftSession]` без eviction
- Domain invariant `max 5 suggestions` є per-session, але не per-app

**Можливі рішення:**
- **A)** LRU cache з max 50 sessions + TTL 1 година
- **B)** Cleanup on `.noteDeleted` event (через існуючий DomainEvent)
- **C)** Зберігати sessions у CoreData (per-domain pattern)

**Рекомендація:** Комбінація **B + C** — видаляти при `.noteDeleted`, persist у CoreData для cold-start recovery. Додати у Sprint 1 tasks.

---

### 6. Race Condition: AI Generation vs Autosave (MEDIUM)

**Факт:** `NoteEditorViewModel.onTextChanged()` запускає save через 800ms (`NoteEditorViewModel.swift:80-91`).

**Проблема:** Сценарій:
1. Користувач пише "Я відчуваю тривогу..."
2. Через 800ms — save викликає `notes.update()` → publishes `.noteUpdated`
3. Паралельно AI generation починається з **старим** контекстом
4. AI повертає suggestions на основі тексту до save

**Vulnerable spots:**
- `AIDraftManager.startDraft()` приймає `context: NoteContent` snapshot, але немає version/etag
- `NoteAIDraftViewModel.start()` — коли викликати, до чи після autosave?

**Можливі рішення:**
- **A)** AI sheet показує "Using content from X seconds ago" indicator
- **B)** Cancel pending AI generation якщо `body` змінився (debounce 1s)
- **C)** Pass `note.date` як version → AI generation ігнорує stale context

**Рекомендація:** Варіант **B** — додати `generationTask?.cancel()` у `NoteAIDraftViewModel` коли `onTextChanged` event від editor.

---

### 7. Foundation Models Latency vs UX (LOW-MEDIUM)

**Факт:** Foundation Models cold-start = 1-3 сек (system model download).

**Проблема:**
- First generation after app launch = poor UX
- План каже "skeleton loader" але не описує progressive disclosure

**Vulnerable spots:**
- `NoteAIDraftSheet.swift` — loading state занадто generic
- Немає telemetry про cold vs warm start latency

**Рекомендація:** Додати у Sprint 1:
- `AIDraftMetric` подія `generation_started(warmCold: Bool)` для analytics
- UI показує "Preparing AI (first time may take longer)" тільки при cold start
- Паралельно показати prompt input — дозволити user type поки model warmup

---

### 8. Telemetry & Privacy Boundary (HIGH for Sprint 2)

**Факт:** План каже "NO content captured — тільки counts + latency + error type".

**Проблема:**
- Що таке "error type"? Може leak sensitive info через error messages
- Foundation Models може повертати error з частинами prompt в повідомленні

**Vulnerable spots:**
- `RemoteLLMDraftService` — error messages можуть містити URL або context
- `MetricsRecorder` — schema не описана, ризик over-collection

**Рекомендація:** Sandbox telemetry:
```swift
enum AIDraftMetric: Sendable {
    case generationStarted(warmCold: Bool)
    case generationCompleted(latencyMs: Int, suggestionCount: Int)
    case generationFailed(errorKind: ErrorKind)  // typed, not message
    case suggestionInserted(index: Int)
    case suggestionRejected(index: Int)
}

enum ErrorKind: String, Codable {
    case timeout, rateLimited, unavailable, emptyResponse, unknown
}
```

Ніяких raw strings у telemetry.

---

### 9. Test Coverage для AI Service (MEDIUM)

**Факт:** `FoundationModelsDraftService` напряму залежить від system framework, який недоступний у тестах/simulator.

**Проблема:**
- Tests НЕ можуть покрити реальний `FoundationModelsDraftService` end-to-end
- Integration tests потребуватимуть `LanguageModelSession` mock — складно

**Vulnerable spots:**
- `MeditateAndNoteTests/FoundationModelsDraftServiceTests.swift` — план не описує що саме тестується без real framework

**Рекомендація:**
- Unit tests: тільки `AIDraftServiceFactory` selection logic + error mapping
- Integration tests: потребують iOS 26+ simulator, run manually перед release
- Snapshot tests для `NoteAIDraftSheet` UI states — стабільні без реального AI

---

### 10. AppContainer DI Growth (LOW)

**Факт:** `AppContainer` вже має 13+ lazy properties (`AppContainer.swift:15-38`).

**Проблема:**
- Sprint 1 додає 2-3 properties (service + manager)
- Sprint 2 додає settings + telemetry
- Sprint 3 додає analyzer + insight manager
- Sprint 4 додає ще більше

**Vulnerable spots:**
- `AppContainer.swift` — файл росте; init() більше не накопичує subscribe блоки (один `startEventListening()` + `handleEvent` switch), але додавання споживачів збільшує case-и в `handleEvent`

**Рекомендація:** Не блокер, але варто планувати refactor `AppContainer` на nested groups (наприклад `AIServicesGroup`) після Sprint 3, якщо файл перевищить ~250 LOC.

---

## Summary: Risk-Ordered Action Items

| Priority | Item | Sprint | Action |
|----------|------|--------|--------|
| CRITICAL | Deployment target strategy | Before Sprint 1 | Decision A/B/C з product owner |
| HIGH | PrivacyInfo.xcprivacy | Sprint 2 (blocker) | Створити файл + privacy labels |
| HIGH | Telemetry error sanitization | Sprint 2 | Use typed ErrorKind enum |
| MEDIUM | DomainEvent blast radius | Sprint 1 | Accept compile-time friction, plan touchpoints |
| MEDIUM | Editor integration pattern | Sprint 1 | Define callback before coding |
| MEDIUM | Session lifecycle | Sprint 1 | Add cleanup on `.noteDeleted` + CoreData persist |
| MEDIUM | Race condition AI vs autosave | Sprint 1 | Cancel-on-text-changed |
| MEDIUM | Test strategy for AI | Sprint 1 | Manual integration + UI snapshot tests |
| LOW | Cold-start UX | Sprint 1 | Progressive disclosure + telemetry warmCold flag |
| LOW | AppContainer growth | After Sprint 3 | Consider nested groups refactor |
