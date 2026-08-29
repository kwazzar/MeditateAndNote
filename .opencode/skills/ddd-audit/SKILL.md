---
name: ddd-audit
description: Use when reviewing a feature, PR, or diff in NightLoom for Domain-Driven Design compliance — checks layer boundaries, anemic-model risk, invariant placement, and DataSource/Manager misuse. Trigger on explicit requests like "check this for DDD", "audit this for DDD", "review architecture", or before marking a significant domain-related feature as done.
---

# DDD Audit — NightLoom

Step-by-step check of code against DDD principles (per Wlaschin/Ozun) and the project's actual persistence pattern (`<X>DataSource`/`<X>Store` + `<X>Manager` with `<X>Providable`/`<X>Manageable` — no generic Repository/ItemManager exists here). Go through each item and give a verdict: ✅ / ⚠️ / ❌ with a short explanation, and for ❌ or ⚠️ a concrete recommended fix.

## 1. Layer boundaries

- [ ] Do Domain files (entities, `<X>DataSource`/`<X>Store` protocols) import `CoreData`, `SwiftUI`, `UIKit`, `Combine`? ❌ if so.
- [ ] Do `NSManagedObject` entities leak outside the concrete `CoreData<X>DataSource`/`CoreData<X>Store` (e.g. into a Manager or ViewModel)? ❌ if so.
- [ ] Does a ViewModel access `CoreDataManager` / `NSManagedObjectContext` directly, bypassing a `<X>DataSource`/`<X>Store` and Manager? ❌ if so.

## 2. Anemic Domain Model

- [ ] Does an Entity expose only `var` fields with no methods protecting invariants (all mutation logic lives in the ViewModel/Manager)? ⚠️/❌ depending on invariant complexity.
- [ ] Are entity mutations done via direct external field assignment (`note.isArchived = true`) instead of a method call (`note.archive()`) when there's a business rule to protect? ❌ if a rule could be violated by direct assignment.

## 3. Value Objects vs primitive obsession

- [ ] Are there places using a "bare" `String`/`Int`/`Double` where the value has its own validity rules (e.g. note length, theme color format)? ⚠️ — candidate for a VO.
- [ ] Are Value Objects immutable (`let`, not `var`)? Compared by value (`Equatable`, ideally `Hashable`)?

## 4. Consistency boundaries

- [ ] Are there mutations that change several related entities at once without a single owner enforcing consistency (each saved separately, no guarantee both succeed/fail together)? ❌ if so — risk of inconsistent state.

## 5. DataSource / Store / Manager pattern

- [ ] Does a new persisted type skip the `<X>DataSource`/`<X>Store` protocol and go straight to a concrete CoreData implementation used everywhere? ❌ — should follow the `NoteDataSource` → `CoreDataNoteDataSource`/`InMemoryNoteDataSource` shape.
- [ ] Does a ViewModel depend on a concrete `<X>Manager` type instead of its `<X>Providable`/`<X>Manageable` protocol? ❌ if so.
- [ ] Does the `<X>DataSource`/`<X>Store` implementation contain business rules (rather than just CRUD/mapping, like `CoreDataNoteDataSource.toNote()`/`.apply()`)? ❌ — business rules belong in the domain or Manager, the DataSource/Store is persistence-only.
- [ ] Is a new Manager throwing generic `Error` instead of a typed `<X>OperationError` (matching `NoteOperationError`)? ⚠️.
- [ ] Is there an invented generic abstraction (a `Repository<Item, LocalDS, RemoteDS>`-style type or an `AnyItemManager`-style type erasure)? ❌ — this project doesn't use that pattern; follow the per-domain protocol convention instead.
- [ ] **Known exception — do not flag:** `CoreDataSessionStore` has no protocol abstraction (unlike `CoreDataStreakStore`, which conforms to `StreakActivityStore`). This is an accepted, pre-existing exception, not a violation to fix. If a *new* type is added without a protocol "because `CoreDataSessionStore` doesn't have one either," that new type ⚠️ still needs its own justification — the exception isn't a precedent to extend by default.

## 6. Dependency Injection

- [ ] Are new dependencies wired up ad hoc inside a View/ViewModel instead of via a `make<X>ViewModel()` factory on `AppContainer`? ❌ if so.

## 7. Domain Events

The project has a real `DomainEvent` mechanism (`Services/DomainEvents/`) — `CoreDataSessionStore.handle()` is a working consumer of it.

- [ ] If an action has side effects across several parts of the system (e.g. "note archived" → update stats, remove from active list) — does it go through `DomainEvent`, or is the logic smeared across multiple manual call sites? ⚠️/❌ if smeared, depending on how many places are touched.

## Response format

After going through all items, give a short summary:
1. List of ❌ (must fix) with file/line and a concrete fix.
2. List of ⚠️ (worth considering) — non-blocking.
3. What's already good (briefly, no elaboration) — so it doesn't read as pure criticism.

Don't rewrite code on your own without user confirmation if the fix is non-trivial (touches a public protocol or several call sites).
