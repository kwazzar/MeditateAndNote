## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

---

## Architecture & DDD (NightLoom / MeditateAndNote)

Goal: generated code follows DDD principles (per Scott Wlaschin) and matches the project's existing architecture, instead of inventing a new one every time.

### Stack

- SwiftUI, CoreData, `@Observable` (migrating away from `ObservableObject`)
- Navigation: custom Router-based approach (NOT `NavigationStack` with logic directly in the View)
- Theming: custom `ThemeManager`

### Layers and dependency direction

Dependencies point inward, toward the domain:

```
Presentation (SwiftUI Views, ViewModels)
        ↓
Application (Managers: NoteManager, StreakTracker, ...)
        ↓
Domain (Entities, Value Objects, DataSource/Store protocols)
        ↑
Infrastructure (Persistence/ — CoreData, UserDefaults implementations of those protocols)
```

Hard rules:
- **The Domain layer never imports `CoreData`, `SwiftUI`, `UIKit`.** It's plain Swift types + protocols.
- CoreData entities (`NSManagedObject`) never leak into Presentation or Application — always mapped to domain models inside the concrete DataSource/Store (e.g. `CoreDataNoteDataSource.toNote()`).
- ViewModels must not contain business logic that changes an entity's invariants — that logic lives in the Entity or in a Manager.
- If unsure which layer a piece of code belongs in, ask instead of guessing.

### Project terminology (the actual pattern in this codebase — verified against graphify)

- **`<X>DataSource` / `<X>Store` protocol** — the persistence contract for a domain type (e.g. `NoteDataSource`, `StreakActivityStore`). Defines `fetchAll`/`fetch`/`save`/`delete`/`deleteAll` or the equivalent for that domain. This is the project's repository abstraction — there is **no generic `Repository<Item, LocalDS, RemoteDS>`**; each domain type gets its own protocol.
- **Concrete implementations** live in `Persistence/` and are named `CoreData<X>DataSource` / `CoreData<X>Store` (e.g. `CoreDataNoteDataSource`, `CoreDataSessionStore`, `CoreDataStreakStore`). Alternate implementations exist for tests/previews/simple storage: `InMemory<X>DataSource` (e.g. `InMemoryNoteDataSource`), `UserDefaults<X>Store` (e.g. `UserDefaultsStreakStore`).
- **Mapping** between `NSManagedObject` and the domain model stays inside the concrete DataSource/Store (`.toNote()`, `.apply()`, `.findOrCreate()` on `CoreDataNoteDataSource`) — never in the Manager or ViewModel.
- **`<X>Manager`** (e.g. `NoteManager`) — orchestrates over a DataSource/Store, exposes read/write split into two protocols: **`<X>Providable`** (read, e.g. `NoteProvidable`) and **`<X>Manageable`** (write, e.g. `NoteManageable`). This is what ViewModels depend on — never on the concrete Manager type directly.
- **`<X>OperationError`** — a typed error enum per domain (e.g. `NoteOperationError` with `.loadFailed` / `.saveFailed` / `.deleteFailed`). New Managers should follow this convention instead of throwing generic `Error`.
- **`CoreDataManager`** — owns the `NSPersistentContainer` stack (`.newBackgroundContext()`, `.buildModel()`). DataSources/Stores use it for contexts; nothing else touches it directly.
- **`AppContainer`** — the DI root, but implemented as **factory methods**, not a registration container: `.makeMainViewModel()`, `.makeNoteEditorViewModel()`, `.makeMeditateSelectViewModel()`, etc. New ViewModels get a `make<X>ViewModel()` factory here, wiring up the right Manager(s).

**Known exception:** `CoreDataSessionStore` (`Persistence/CoreDataSessionStore.swift`) is used as a concrete type with no protocol abstraction and no alternate implementation — unlike `CoreDataStreakStore`, which does conform to `StreakActivityStore` (the same protocol `UserDefaultsStreakStore` implements). Don't flag `CoreDataSessionStore`'s lack of a protocol as a violation; it's an accepted exception, not the target pattern to copy for new types.

**Domain Events:** there's an existing `DomainEvent` type (see `Services/DomainEvents/`) — `CoreDataSessionStore.handle()` reacts to one. New cross-cutting side effects (an action that needs to update state in more than one Store/Manager) should go through this mechanism rather than being wired manually across call sites.

> This section reflects the codebase as of the graphify snapshot. Re-verify with `graphify query`/`graphify explain` if the structure has moved on.

### How to approach a new feature (two-step process)

**Step 1 — Domain first.** Before writing code, briefly describe:
- Which new/changed Entities or Value Objects appear
- Whether an existing `<X>DataSource`/`<X>Store` protocol fits, or a new one is needed
- Which invariants the domain must protect, and where they should live (Entity vs Manager)

Present this as a short plan before writing any code. For a new domain type, use the `new-aggregate` skill.

**Step 2 — Implement layer by layer**, in this order: Domain (protocol + entity) → Infrastructure (`CoreData<X>DataSource`/`Store` in `Persistence/`) → Application (`<X>Manager` + `<X>Providable`/`<X>Manageable`) → Presentation (ViewModel via `AppContainer` factory).

### "Bad / Good" example

Bad (anemic model, logic in the ViewModel):
```swift
func archiveNote(_ note: Note) {
    note.isArchived = true
    note.archivedAt = Date()
    noteManager.update(note)
}
```

Good (behavior encapsulated in the Entity):
```swift
extension Note {
    mutating func archive() {
        guard !isArchived else { return }
        isArchived = true
        archivedAt = .now
    }
}

func archiveNote(_ note: Note) {
    var note = note
    note.archive()
    noteManager.update(note)
}
```
Why: the rule "an already-archived note can't be archived again" is a domain invariant — it belongs in the Entity, not scattered across UI-layer call sites.

### Forbidden

- Business logic (validation, invariants, state transitions) inside a SwiftUI View.
- ViewModel accessing `CoreDataManager` / `NSManagedObjectContext` directly, bypassing a `<X>DataSource`/`<X>Store` and the Manager.
- ViewModel depending on a concrete `<X>Manager` type instead of its `<X>Providable`/`<X>Manageable` protocol.
- New DI wiring that bypasses `AppContainer`'s `make<X>ViewModel()` factories.
- Inventing a new generic Repository/Manager abstraction — follow the existing per-domain `DataSource`/`Store` + `Manager` convention instead.

### Definition of done

Before considering a task complete:
1. Run the build/tests via XcodeBuildMCP.
2. Verify Domain files don't import `CoreData`/`SwiftUI`.
3. If Router/navigation was touched, verify the ViewModel doesn't reference a concrete View directly.
4. For a full DDD-compliance check on the feature, use the `ddd-audit` skill.

### Available skills

- `ddd-audit` — checklist for reviewing code/PRs against DDD principles. Invoke before finishing a significant feature, or on explicit request like "check this for DDD compliance".
- `new-aggregate` — recipe for adding a new domain type in the project's actual style (`<X>DataSource`/`<X>Store` protocol + `CoreData`/`InMemory`/`UserDefaults` implementation + `<X>Manager` with `<X>Providable`/`<X>Manageable`). Invoke when adding a new domain entity.