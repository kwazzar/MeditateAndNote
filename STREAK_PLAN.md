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
| S5 | Local notification reminders + Settings UI + navigation fix | ✅ `46a9b4a` |
| S3 | Date-range filtering (7/30/90 days) + weekly drill-down | ⏳ planned |
| S4 | Core day (meditation + note same day = streak day) | ⏳ planned |
| S6 | Trend line / extended stats | ⏳ planned |

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

## S3 — Date Ranges & Deeper Drill-down

- Range selector on the heatmap/detail view: 7 / 30 / 90 days.
- Weekly aggregation graph (drill-down from the weekday heatmap).
- Preserve S2 animations when switching ranges.

## S4 — Core Day

- Enforce the invariant that a streak day requires **both** a meditation
  session and a note on the same calendar day.
- Surface partial-day state in the UI (meditation done, note pending, and
  vice versa) — see existing `todayProgress` pills in `StreakDetailView`.

## S5 — Reminders (done)

- Reminder settings in the app: toggle, time picker, weekday selection.
- Local notifications scheduled for the selected weekdays (horizon 7),
  `UNUserNotificationCenter` with foreground delegate.
- `ReminderSettings` value object, `UserDefaultsReminderSettingsStore`,
  `ReminderManager` (`ReminderProvidable` / `ReminderManageable`).
- Recommendation `setReminder` enables a reminder for the weakest weekday.
- Fixed SettingsView back navigation (native toolbar item).
- 18 new tests. **146/146 passing.**

## S6 — Trends

- Trend line / longer-horizon statistics on top of the streak data.
- Concrete scope to be finalized (e.g. streak length distribution,
  completion-rate by weekday, average streak recovery time).

## Definition of done

1. Build + tests are green (`146` currently).
2. Domain files stay free of `CoreData` / `SwiftUI`.
3. Navigation changes don't leak concrete Views into ViewModels.
4. `ddd-audit` review passes for significant features.
5. `graphify update .` keeps the knowledge graph current.