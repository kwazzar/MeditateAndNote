# Streak Improvements Plan

Iterative sprint plan for the streak engine, insights, and recommendations
in **MeditateAndNote**. Each sprint is implemented DDD-style: Domain → Infrastructure
(Persistence) → Application (Manager) → Presentation. Commits land only after
explicit user approval.

## Progress

| Sprint | Scope | Status |
| ------ | ----- | ------ |
| S1 | Streak header, calendar grid, progress pills, insight engine | ✅ `34e12e3` |
| S2 | Weekday heatmap, drill-down detail view, animated transitions | ✅ `c9dd79b` |
| S3 | Date-range filtering (7/30/90 days) + weekly drill-down bars | ✅ `8607926` |
| S4 | Core day invariant (meditation + note) + partial-day surface | ✅ `d3b58a9` |
| S5 | Local notification reminders + Settings UI + navigation fix | ✅ `46a9b4a` |
| S6 | Lifetime patterns — distribution, resilience, break pattern | ✅ `a5cddae` |
| S7 | DDD cleanup — protocol boundaries, cache invalidation, concrete leaks | ⏳ planned |

## S1 — Foundations (done)

- Streak header: current / best / total complete days.
- Daily activity model: meditation + note tracked per day.
- Calendar grid for the current month (day cells, progress coloring).
- `StreakInsightEngine` — insight generation + recommendation actions.

## S2 — Heatmap & Drill-down (done)

- Weekday heatmap across the last 5 weeks (`WeekdayHeatmapView`).
- Drill-down detail view with per-day activity breakdown.
- Staggered bar entrance + fade/slide transitions.
- Insights caching and recommendation actions (`StreakInsightManager`).

## S3 — Date Ranges & Deeper Drill-down (done)

- `StreakRange` value object (`.last7` / `.last30` / `.last90`) — pure
  domain, no CoreData / SwiftUI.
- `StreakInsightEngine` re-derived with `range:` parameter: completion rate,
  weekly heatmap, partial-day gap, time-of-day, trend, and balance insights
  all filter to the selected window.
- New `WeeklyBucket` value object + `engine.weeklyBreakdown(from:range:today:)`
  producing week-aligned buckets whose totals sum exactly to `range.dayCount`.
- Range-aware `StreakInsightManager` with per-`(range, signature)` caching.
- `InsightsViewModel.selectedRange` (`@Observable` `didSet`) re-derives
  insights, recommendations, and weekly breakdown on change; same-range writes
  are a no-op.
- Segmented `Picker` in `InsightsSection` (7D / 30D / 90D).
- `WeeklyBreakdownChart` in `InsightDetailView`: animated bars, color-coded
  by completion rate, with "best week" callout.
- 21 new tests. **337/337 passing.**

## S4 — Core Day (done)

- The streak invariant was already centralized in
  `DailyActivity.isComplete = hasMeditation && hasNote` and enforced by
  every `StreakEngine.updateStreak / recalculate / checkStreakBreak`
  consumer.
- New `CoreDayState` enum (`.empty / .meditationOnly / .noteOnly / .complete`)
  makes the four valid day-states first-class instead of two booleans +
  one computed bool. `coreDayState` is derived on `DailyActivity`.
- New `StreakDayDetail` value object (`date / state / meditationTime /
  noteTime / isToday / missingAction`) plus `StreakTracker.dayDetail(for:)`
  so the day-detail sheet depends on a value object rather than the engine.
- `DayCellView`: bidirectional partial indicator — orange dot for
  `.meditationOnly`, note-color dot for `.noteOnly` — shown for today
  AND the last 7 days so the user can see *where* the streak broke.
- `StreakDetailView.todayProgress`: pills are now tappable CTAs that
  navigate to Meditation / Note when the day is partial, with a hint
  label explaining what to do. `coreDayState` is observed via animation.
- New `StreakDayDetailSheet`: tap any day cell → opens a sheet with
  state, both timestamps, and a "Complete the day" action button.
- 18 new tests. **355/355 passing.**

## S5 — Reminders (done)

- Reminder settings in the app: toggle, time picker, weekday selection.
- Local notifications scheduled for the selected weekdays (horizon 7),
  `UNUserNotificationCenter` with foreground delegate.
- `ReminderSettings` value object, `UserDefaultsReminderSettingsStore`,
  `ReminderManager` (`ReminderProvidable` / `ReminderManageable`).
- Recommendation `setReminder` enables a reminder for the weakest weekday.
- Fixed SettingsView back navigation (native toolbar item).
- 18 new tests. **146/146 passing.**

## S6 — Lifetime Patterns (done)

Three range-independent insights that describe the *shape* of the user's
streak history, not a windowed metric. They share an engine helper and
are cached by snapshot signature (no range key), so they stay stable as
the user toggles 7D / 30D / 90D.

- New domain value objects in `Models/StreakInsight.swift`:
  `StreakLengthDistribution(buckets:, totalStreaks:, medianLength:)` —
  histogram of streak runs into the fixed buckets
  `[1 / 2 / 3 / 4-6 / 7-13 / 14+]`.
  `StreakResilience(avgRecoveryDays:, longestRecoveryDays:,
  totalRecoveries:, survivalByDay:)` — recovery profile and
  P(>=n+1 | >=n) survival curve.
  `WeekdayHeatmapData.Day` gains `breakRate: Double` (0 for
  range-windowed heatmaps, populated only by the lifetime path).
- `StreakInsightEngine` gets a private `extractStreakRuns(from:)`
  helper (segments activities into consecutive complete-day runs and
  records the weekday of the first missing day after each run). Three
  public methods feed off it:
  `streakLengthDistribution(from:)`,
  `resilience(from:)`,
  `weekdayBreakPattern(from:)`,
  `weekdayBreakHeatmapData(from:)`.
- `StreakInsightProvidable` exposes the lifetime surface (4 methods);
  `StreakInsightManager` caches the results keyed by snapshot signature
  — no range pollution.
- `InsightsViewModel` splits `refresh()` into `refreshRangeAware()`
  (re-derived on `selectedRange` change) and `refreshLifetime()`
  (snapshot-driven only). New private-set properties:
  `streakLengthDistribution`, `resilience`, `weekdayBreakPattern`,
  `weekdayBreakHeatmap`.
- New `LifetimePatternsSection` view hosts three custom cards
  (distribution histogram, resilience tiles, break-pattern bars),
  rendered below `InsightsSection` in `StreakDetailView`.
- 8 new tests. **363/363 passing.**

## S7 — DDD Cleanup (planned)

Align the streak module with the project's DDD conventions (per AGENTS.md and ddd-audit):

1. **StreakInsightManager → protocol dependency**  
   Introduce `StreakSnapshotProvidable` protocol (`func snapshot() -> StreakSnapshot`).  
   `StreakTracker` already has `var snapshot: StreakSnapshot` — conform trivially.  
   `StreakInsightManager` takes `any StreakSnapshotProvidable` instead of concrete `StreakTracker`.  
   Enables mocked `StreakInsightManagerTests` without a real engine.

2. **Cache invalidation wired to production flow**  
   `StreakTracker` (or `StreakEngine`) emits a `DomainEvent` on mutation (`markNoteCreated`, `markMeditationCompleted`, `recalculate`, `checkStreakBreak`).  
   `StreakInsightManager` subscribes via `handle(_: DomainEvent)` → calls `invalidateCache()`.  
   Eliminates the stale-cache bug where views show outdated insights after streak mutations.

3. **StreakDetailView drops concrete `StreakTracker` injection**  
   Read `@Environment(StreakTracker.self)` (consistent with `MainView`, `StreakHeaderView`).  
   Remove `let streakTracker: StreakTracker` parameter and its wiring from `Destination-ViewMapping.swift`.  
   Router no longer leaks concrete manager into View signature.

4. **Previews use `AppContainer.preview()` or stubs**  
   Remove manual `StreakTracker()` / `StreakInsightManager(streakTracker:)` construction in `StreakDetailView`, `MainView`, `RootContainer`.  
   Either inject via `AppContainer` preview factory or provide a `StubInsightManager` / `StubStreakTracker` conforming to the new protocols.

5. **`StreakTracker.checkStreakBreak()` made private**  
   It is only called from `init`; no external caller needs it.  
   Removes the foot-gun where a public mutating method bypasses `apply { }` persistence.

6. **Housekeeping**  
   - Move `StreakSnapshot` from `Services/StreakTracker.swift` → `Models/StreakInsight.swift` (or new `Models/StreakSnapshot.swift`).  
   - Move `UserDefaultsStreakStore` from `Services/StreakTracker.swift` → `Persistence/UserDefaultsStreakStore.swift` (mirrors `UserDefaultsReminderSettingsStore`).  
   - Engine helpers that bake `Date()` (`weekdayCompletionStats`, `partialDayInsights`, `timeOfDayInsights`, `balanceInsights`) take `today: Date = Date()` parameter like `weeklyBreakdown` does.  
   - Consider `StreakInsight` / `UserRecommendation` identity by `(category, title)` instead of `UUID()` for stable SwiftUI animations on range toggle. (Lower priority.)

1. Build + tests are green (`363` currently).
2. Domain files stay free of `CoreData` / `SwiftUI`.
3. Navigation changes don't leak concrete Views into ViewModels.
4. `ddd-audit` review passes for significant features.
5. `graphify update .` keeps the knowledge graph current.