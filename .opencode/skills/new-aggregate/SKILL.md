---
name: new-aggregate
description: Use when adding a new domain Entity, Value Object, or persisted domain type to NightLoom. Provides the project's actual pattern (per-domain DataSource/Store protocol + CoreData/InMemory/UserDefaults implementation + Manager split into Providable/Manageable) so new domain code matches existing style instead of inventing a parallel mechanism. Trigger on requests like "add a new entity", "create a new domain type", "add persistence for X".
---

# Adding a new domain type — NightLoom

Recipe for adding a new persisted domain entity in the project's existing style, verified against the codebase graph. There is **no generic `Repository<Item, LocalDS, RemoteDS>`** and **no `AnyItemManager`** in this project — each domain type gets its own protocol + Manager, following the pattern below.

## Step 0 — Domain first (mandatory before writing code)

Briefly answer:
1. Is this a new Entity (has identity, changes over time) or a Value Object (immutable, compared by value)?
2. Does it need its own persistence, or does it belong inside an existing domain type (e.g. a field on `Note`)?
3. Which invariants does it protect (what states must never become possible)?
4. Does an existing `<X>DataSource`/`<X>Store` already cover this, or is a new protocol needed?

Present this plan to the user before generating code.

## Step 1 — Domain layer: Entity + persistence protocol

Plain Swift type, no `CoreData`/`SwiftUI` imports:

```swift
struct <NewEntity>: Identifiable, Equatable {
    let id: UUID
    private(set) var <field>: <Type>
    private(set) var <invariantGuardedField>: Bool

    init(id: UUID = UUID(), <field>: <Type>) {
        self.id = id
        self.<field> = <field>
        self.<invariantGuardedField> = false
    }

    // Behavior that protects the invariant — not a bare external assignment
    mutating func <domainAction>() {
        guard !<invariantGuardedField> else { return }
        <invariantGuardedField> = true
    }
}
```

Define the persistence contract as its own protocol, following the `NoteDataSource` shape:

```swift
protocol <NewEntity>DataSource {
    func fetchAll() throws -> [<NewEntity>]
    func fetch(id: UUID) throws -> <NewEntity>?
    func save(_ item: <NewEntity>) throws
    func delete(id: UUID) throws
    func deleteAll() throws
}
```

(Use `<NewEntity>Store` instead of `DataSource` if the shape doesn't fit CRUD — see `StreakActivityStore` for a non-CRUD example.)

## Step 2 — Infrastructure layer (`Persistence/`)

- Implement `CoreData<NewEntity>DataSource` in `Persistence/`, mirroring `CoreDataNoteDataSource`: use `CoreDataManager` for contexts, keep the `NSManagedObject ↔ <NewEntity>` mapping inside this type (`.to<NewEntity>()`, `.apply()`, `.findOrCreate()` — same naming as `CoreDataNoteDataSource`).
- If a lightweight/non-CoreData implementation is useful (tests, previews, simple key-value data), add `InMemory<NewEntity>DataSource` (see `InMemoryNoteDataSource`) or `UserDefaults<NewEntity>Store` (see `UserDefaultsStreakStore`) — whichever fits the storage need.
- Don't let `NSManagedObject` or `CoreDataManager` be visible outside this file.

## Step 3 — Application layer: Manager

Create `<NewEntity>Manager`, orchestrating over the DataSource, split into two protocols the same way `NoteManager` splits into `NoteProvidable`/`NoteManageable`:

```swift
protocol <NewEntity>Providable {
    func <newEntity>(id: UUID) -> <NewEntity>?
    func <newEntity>s() -> [<NewEntity>]
}

protocol <NewEntity>Manageable {
    func add(_ item: <NewEntity>) throws
    func update(_ item: <NewEntity>) throws
    func delete(id: UUID) throws
}

enum <NewEntity>OperationError: Error {
    case loadFailed
    case saveFailed
    case deleteFailed
}

final class <NewEntity>Manager: <NewEntity>Providable, <NewEntity>Manageable {
    private let dataSource: <NewEntity>DataSource
    init(dataSource: <NewEntity>DataSource) { self.dataSource = dataSource }
    // ...
}
```

ViewModels must depend on `<NewEntity>Providable`/`<NewEntity>Manageable`, never on the concrete `<NewEntity>Manager`.

## Step 4 — Presentation layer

Add a `make<X>ViewModel()` factory to `AppContainer`, wiring the concrete `CoreData<NewEntity>DataSource` into `<NewEntity>Manager` and injecting it into the ViewModel — the same way `AppContainer.makeNoteEditorViewModel()` wires `NoteManager`.

The ViewModel calls domain methods (`entity.<domainAction>()`) and Manager methods, never touches `CoreDataManager`/`NSManagedObjectContext` directly, and contains no invariant checks — those live in the Entity.

## Step 5 — Self-check

Before finishing, run the `ddd-audit` skill against the newly created code.
